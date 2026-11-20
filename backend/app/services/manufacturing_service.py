"""Manufacturing Analysis Service - CNC setup planning and operation mapping."""

import logging
import math
from typing import Any
from uuid import uuid4

from app.core.config import get_settings
from app.models.material import Material as MaterialModel
from app.schemas.cad_specs import (
    BoundingBox3D, CostEstimate, Feature, FeatureDimensions, ManufacturingAnalysis,
    Operation, OperationType, Setup, ToolCategory, Vector3D,
)

settings = get_settings()
logger = logging.getLogger(__name__)


class ManufacturingService:
    """Service for 3-axis CNC manufacturing analysis and cost estimation."""

    def __init__(self) -> None:
        self.settings = settings
        self.stock_margin_mm = settings.STOCK_MARGIN_MM
        self.tool_change_time_s = settings.TOOL_CHANGE_TIME_S
        self.setup_time_min = settings.SETUP_TIME_MIN
        self.inspection_time_per_feature_min = settings.INSPECTION_TIME_PER_FEATURE_MIN

        # Configurable machining parameters (mm/min for feed, m/min for speed)
        # These are indicative defaults - should come from machine/tooling DB
        self.default_cutting_params = {
            OperationType.FACE_MILLING: {"speed": 200, "feed": 800, "doc": 3.0, "stepover": 0.7},
            OperationType.POCKET_MILLING: {"speed": 150, "feed": 600, "doc": 2.0, "stepover": 0.5},
            OperationType.SLOT_MILLING: {"speed": 150, "feed": 500, "doc": 2.0, "stepover": 1.0},
            OperationType.PROFILE_MILLING: {"speed": 180, "feed": 700, "doc": 2.0, "stepover": 0.3},
            OperationType.DRILLING: {"speed": 80, "feed": 150, "doc": 0, "stepover": 0},
            OperationType.REAMING: {"speed": 40, "feed": 100, "doc": 0, "stepover": 0},
            OperationType.TAPPING: {"speed": 15, "feed": 75, "doc": 0, "stepover": 0},
            OperationType.BORING: {"speed": 60, "feed": 100, "doc": 0.5, "stepover": 0},
            OperationType.COUNTERBORING: {"speed": 60, "feed": 100, "doc": 1.0, "stepover": 0},
            OperationType.COUNTERSINKING: {"speed": 60, "feed": 80, "doc": 1.0, "stepover": 0},
            OperationType.CHAMFERING: {"speed": 150, "feed": 500, "doc": 1.0, "stepover": 0},
            OperationType.ENGRAVING: {"speed": 200, "feed": 400, "doc": 0.5, "stepover": 0},
            OperationType.DEBURRING: {"speed": 200, "feed": 600, "doc": 0.3, "stepover": 0},
            OperationType.INSPECTION: {"speed": 0, "feed": 0, "doc": 0, "stepover": 0},
        }

        # Tool category mapping
        self.feature_to_tool = {
            "through_hole": ToolCategory.DRILL,
            "blind_hole": ToolCategory.DRILL,
            "counterbore": ToolCategory.COUNTERBORE_TOOL,
            "countersink": ToolCategory.COUNTERSINK_TOOL,
            "tapped_hole_candidate": ToolCategory.TAP,
            "reamed_hole_candidate": ToolCategory.REAMER,
            "cylindrical_bore": ToolCategory.BORING_BAR,
            "rectangular_pocket": ToolCategory.END_MILL,
            "circular_pocket": ToolCategory.END_MILL,
            "complex_pocket": ToolCategory.END_MILL,
            "open_slot": ToolCategory.SLOT_DRILL,
            "closed_slot": ToolCategory.SLOT_DRILL,
            "t_slot": ToolCategory.T_SLOT_CUTTER,
            "dovetail_slot": ToolCategory.DOVETAIL_CUTTER,
            "step": ToolCategory.END_MILL,
            "shoulder": ToolCategory.END_MILL,
            "external_profile": ToolCategory.END_MILL,
            "internal_profile": ToolCategory.END_MILL,
            "chamfer": ToolCategory.CHAMFER_TOOL,
            "fillet": ToolCategory.BALL_END_MILL,
            "rounded_corner": ToolCategory.BALL_END_MILL,
            "groove": ToolCategory.END_MILL,
            "recess": ToolCategory.END_MILL,
            "boss": ToolCategory.END_MILL,
            "rib": ToolCategory.END_MILL,
            "thread_geometry": ToolCategory.THREAD_MILL,
        }

        self.feature_to_operation = {
            "through_hole": OperationType.DRILLING,
            "blind_hole": OperationType.DRILLING,
            "counterbore": OperationType.COUNTERBORING,
            "countersink": OperationType.COUNTERSINKING,
            "tapped_hole_candidate": OperationType.TAPPING,
            "reamed_hole_candidate": OperationType.REAMING,
            "cylindrical_bore": OperationType.BORING,
            "rectangular_pocket": OperationType.POCKET_MILLING,
            "circular_pocket": OperationType.POCKET_MILLING,
            "complex_pocket": OperationType.POCKET_MILLING,
            "open_slot": OperationType.SLOT_MILLING,
            "closed_slot": OperationType.SLOT_MILLING,
            "t_slot": OperationType.SLOT_MILLING,
            "dovetail_slot": OperationType.SLOT_MILLING,
            "step": OperationType.PROFILE_MILLING,
            "shoulder": OperationType.PROFILE_MILLING,
            "external_profile": OperationType.PROFILE_MILLING,
            "internal_profile": OperationType.PROFILE_MILLING,
            "chamfer": OperationType.CHAMFERING,
            "fillet": OperationType.PROFILE_MILLING,
            "rounded_corner": OperationType.PROFILE_MILLING,
            "groove": OperationType.SLOT_MILLING,
            "recess": OperationType.POCKET_MILLING,
            "boss": OperationType.PROFILE_MILLING,
            "rib": OperationType.PROFILE_MILLING,
            "thread_geometry": OperationType.TAPPING,
        }

    def analyze_manufacturability(
        self,
        cad_specs: Any,
        machine_id: str = "generic_3axis",
        material_id: str = "aluminum_6061",
    ) -> ManufacturingAnalysis:
        """
        Analyze part for 3-axis CNC manufacturability.
        Determines setups, maps features to operations, estimates times.
        """
        features = cad_specs.features if cad_specs.features else []
        geometry = cad_specs.geometry_summary

        # Determine stock dimensions from bounding box
        stock_dimensions = None
        stock_volume_cm3 = 0.0
        stock_weight_kg = 0.0
        material_removal_volume_cm3 = 0.0

        if geometry and geometry.bbox:
            bbox = geometry.bbox
            dx = bbox.max.x - bbox.min.x
            dy = bbox.max.y - bbox.min.y
            dz = bbox.max.z - bbox.min.z

            # Add stock margin
            stock_dx = dx + 2 * self.stock_margin_mm
            stock_dy = dy + 2 * self.stock_margin_mm
            stock_dz = dz + 2 * self.stock_margin_mm

            stock_dimensions = BoundingBox3D(
                min=Vector3D(x=bbox.min.x - self.stock_margin_mm,
                             y=bbox.min.y - self.stock_margin_mm,
                             z=bbox.min.z - self.stock_margin_mm),
                max=Vector3D(x=bbox.max.x + self.stock_margin_mm,
                             y=bbox.max.y + self.stock_margin_mm,
                             z=bbox.max.z + self.stock_margin_mm),
            )

            stock_volume_cm3 = (stock_dx * stock_dy * stock_dz) / 1000.0  # mm3 to cm3

            # Estimate material removal volume
            part_volume_cm3 = geometry.volume / 1000.0 if geometry.volume else 0
            material_removal_volume_cm3 = stock_volume_cm3 - part_volume_cm3

            # Estimate stock weight (assume aluminum 2700 kg/m3 = 2.7 g/cm3)
            density = 2.7  # g/cm3 for aluminum
            stock_weight_kg = stock_volume_cm3 * density / 1000.0

        # Determine setups based on feature orientations
        setups = self._determine_setups(features, geometry)

        # Map features to operations
        operations = self._map_features_to_operations(features, setups)

        # Calculate times
        total_cutting_time = sum(op.estimated_time_min for op in operations)
        total_tool_change_time = len(set(tool for op in operations for tool in [op.tool_category])) * self.tool_change_time_s / 60.0
        total_setup_time = len(setups) * self.setup_time_min
        total_inspection_time = len(features) * self.inspection_time_per_feature_min
        total_estimated_time = (total_cutting_time + total_tool_change_time +
                                total_setup_time + total_inspection_time)

        # Determine machining difficulty
        difficulty = self._assess_difficulty(features, setups, operations)

        # Identify inaccessible features
        inaccessible = self._identify_inaccessible(features, setups)

        # Generate warnings
        warnings = self._generate_warnings(features, setups, operations, geometry)

        return ManufacturingAnalysis(
            setups=setups,
            operations=operations,
            total_cutting_time_min=round(total_cutting_time, 1),
            total_tool_change_time_min=round(total_tool_change_time, 1),
            total_setup_time_min=round(total_setup_time, 1),
            total_inspection_time_min=round(total_inspection_time, 1),
            total_estimated_time_min=round(total_estimated_time, 1),
            material_removal_volume_cm3=round(material_removal_volume_cm3, 1),
            stock_dimensions=stock_dimensions,
            stock_volume_cm3=round(stock_volume_cm3, 1),
            stock_weight_kg=round(stock_weight_kg, 2),
            machining_difficulty=difficulty,
            inaccessible_features=inaccessible,
            warnings=warnings,
        )

    def _determine_setups(
        self,
        features: list[Feature],
        geometry: Any,
    ) -> list[Setup]:
        """Determine required machining setups based on feature orientations."""
        setups = []

        # Group features by approach direction (simplified: Z-up is primary)
        # Features with different primary approach directions need separate setups
        primary_features = [f for f in features if f.axis]
        secondary_features = [f for f in features if not f.axis and f.type in (
            "rectangular_pocket", "circular_pocket", "complex_pocket",
            "external_profile", "internal_profile", "face_milling"
        )]

        # Setup 1: Primary (Z-up)
        setup1_features = [f.feature_id for f in primary_features if f.axis and abs(f.axis.z) > 0.7]
        setup1_features.extend(f.feature_id for f in secondary_features)

        if setup1_features:
            setups.append(Setup(
                setup_id=f"S-{uuid4().hex[:6].upper()}",
                orientation=Vector3D(x=0.0, y=0.0, z=1.0),
                origin=Vector3D(x=0.0, y=0.0, z=0.0),
                features=setup1_features,
                description="Primary setup - Z-up machining",
            ))

        # Setup 2: Rotated 90° for side features
        setup2_features = [f.feature_id for f in primary_features if f.axis and abs(f.axis.x) > 0.7]
        if setup2_features:
            setups.append(Setup(
                setup_id=f"S-{uuid4().hex[:6].upper()}",
                orientation=Vector3D(x=1.0, y=0.0, z=0.0),
                origin=Vector3D(x=0.0, y=0.0, z=0.0),
                features=setup2_features,
                description="Secondary setup - rotated 90° for side features",
            ))

        # Setup 3: Rotated for other side
        setup3_features = [f.feature_id for f in primary_features if f.axis and abs(f.axis.y) > 0.7]
        if setup3_features:
            setups.append(Setup(
                setup_id=f"S-{uuid4().hex[:6].upper()}",
                orientation=Vector3D(x=0.0, y=1.0, z=0.0),
                origin=Vector3D(x=0.0, y=0.0, z=0.0),
                features=setup3_features,
                description="Tertiary setup - rotated for Y-axis features",
            ))

        # If no setups created but features exist, create default
        if not setups and features:
            setups.append(Setup(
                setup_id=f"S-{uuid4().hex[:6].upper()}",
                orientation=Vector3D(x=0.0, y=0.0, z=1.0),
                origin=Vector3D(x=0.0, y=0.0, z=0.0),
                features=[f.feature_id for f in features],
                description="Default setup - all features",
            ))

        return setups

    def _map_features_to_operations(
        self,
        features: list[Feature],
        setups: list[Setup],
    ) -> list[Operation]:
        """Map recognized features to machining operations."""
        operations = []

        # Assign features to setups (first setup that contains them, or first setup)
        setup_feature_map = {}
        for setup in setups:
            for fid in setup.features:
                if fid not in setup_feature_map:
                    setup_feature_map[fid] = setup.setup_id

        default_setup_id = setups[0].setup_id if setups else f"S-{uuid4().hex[:6].upper()}"

        for feature in features:
            setup_id = setup_feature_map.get(feature.feature_id, default_setup_id)

            # Get operation type and tool category for this feature
            op_type = self.feature_to_operation.get(feature.type, OperationType.PROFILE_MILLING)
            tool_cat = self.feature_to_tool.get(feature.type, ToolCategory.END_MILL)

            # Estimate time
            est_time = self._estimate_operation_time(op_type, feature)

            # Get cutting parameters
            params = self.default_cutting_params.get(op_type, {
                "speed": 150, "feed": 500, "doc": 2.0, "stepover": 0.5,
            })

            # Determine tool dimensions from feature
            tool_diameter = None
            if feature.dimensions and feature.dimensions.diameter:
                tool_diameter = feature.dimensions.diameter * 0.9  # Tool slightly smaller than hole
            elif feature.dimensions and feature.dimensions.width:
                tool_diameter = feature.dimensions.width * 0.8

            # For operations that don't use depth/stepover (drilling, tapping, etc.), use None
            depth_cut = params["doc"] if params["doc"] > 0 else None
            stepover = params["stepover"] if params["stepover"] > 0 else None

            # Assumptions
            assumptions = [
                f"Standard {tool_cat.value} used",
                f"Material: {settings.DEFAULT_MATERIAL}",
                "Fixturing assumed adequate",
                "No fixturing changes within setup",
            ]

            # Warnings
            warnings = []
            if feature.accessibility and feature.accessibility.collision_risk in ("difficult", "inaccessible"):
                warnings.append(f"Feature {feature.feature_id} may have limited accessibility")

            operations.append(Operation(
                operation_id=f"OP-{uuid4().hex[:6].upper()}",
                feature_ids=[feature.feature_id],
                operation_type=op_type,
                tool_category=tool_cat,
                setup_id=setup_id,
                estimated_time_min=est_time,
                tool_diameter=tool_diameter,
                tool_length=None,
                cutting_speed_m_min=params["speed"] if params["speed"] > 0 else None,
                feed_mm_min=params["feed"] if params["feed"] > 0 else None,
                depth_of_cut_mm=depth_cut,
                stepover_mm=stepover,
                passes=1,
                assumptions=assumptions,
                confidence=feature.confidence,
                warnings=warnings,
            ))

        # Add facing operation if there are large planar faces
        if any(f.type in ("flat_face", "planar_face") for f in features):
            operations.append(Operation(
                operation_id=f"OP-{uuid4().hex[:6].upper()}",
                feature_ids=[f.feature_id for f in features if f.type in ("flat_face", "planar_face")],
                operation_type=OperationType.FACE_MILLING,
                tool_category=ToolCategory.FACE_MILL,
                setup_id=default_setup_id,
                estimated_time_min=5.0,
                tool_diameter=63.0,
                cutting_speed_m_min=200.0,
                feed_mm_min=800.0,
                depth_of_cut_mm=2.0,
                stepover_mm=44.0,
                passes=1,
                assumptions=["Initial face mill to establish datum"],
                confidence=0.8,
                warnings=[],
            ))

        return operations

    def _estimate_operation_time(
        self,
        op_type: OperationType,
        feature: Feature,
    ) -> float:
        """Estimate cutting time for an operation based on feature dimensions."""
        params = self.default_cutting_params.get(op_type, {
            "speed": 150, "feed": 500, "doc": 2.0, "stepover": 0.5,
        })

        # Base time by operation type (minutes)
        base_times = {
            OperationType.DRILLING: 1.0,
            OperationType.REAMING: 2.0,
            OperationType.TAPPING: 3.0,
            OperationType.BORING: 2.5,
            OperationType.COUNTERBORING: 2.0,
            OperationType.COUNTERSINKING: 1.5,
            OperationType.CHAMFERING: 2.0,
            OperationType.FACE_MILLING: 5.0,
            OperationType.POCKET_MILLING: 15.0,
            OperationType.SLOT_MILLING: 8.0,
            OperationType.PROFILE_MILLING: 10.0,
            OperationType.ENGRAVING: 3.0,
            OperationType.DEBURRING: 2.0,
            OperationType.INSPECTION: 2.0,
        }

        base_time = base_times.get(op_type, 5.0)

        # Adjust based on feature size
        size_factor = 1.0
        if feature.dimensions:
            if feature.dimensions.diameter:
                size_factor = max(0.5, min(3.0, feature.dimensions.diameter / 10.0))
            elif feature.dimensions.width:
                size_factor = max(0.5, min(3.0, feature.dimensions.width / 20.0))
            elif feature.dimensions.depth:
                size_factor = max(0.5, min(3.0, feature.dimensions.depth / 10.0))

        # Adjust based on confidence (lower confidence = more time for verification)
        conf_factor = 1.0 + (1.0 - feature.confidence) * 0.5

        return round(base_time * size_factor * conf_factor, 1)

    def _assess_difficulty(
        self,
        features: list[Feature],
        setups: list[Setup],
        operations: list[Operation],
    ) -> str:
        """Assess overall machining difficulty."""
        score = 0

        # Number of setups
        score += len(setups) * 10

        # Number of operations
        score += len(operations) * 2

        # Feature types
        for f in features:
            if f.type in ("undercut_candidate",):
                score += 20  # Undercuts are difficult for 3-axis
            elif f.type in ("complex_pocket",):
                score += 10
            elif f.type in ("tapped_hole_candidate", "reamed_hole_candidate"):
                score += 5

        # Accessibility issues
        for f in features:
            if f.accessibility and f.accessibility.collision_risk in ("difficult", "inaccessible"):
                score += 15

        if score <= 20:
            return "easy"
        elif score <= 50:
            return "medium"
        elif score <= 80:
            return "hard"
        else:
            return "very_hard"

    def _identify_inaccessible(
        self,
        features: list[Feature],
        setups: list[Setup],
    ) -> list[str]:
        """Identify features that may be inaccessible for 3-axis machining."""
        inaccessible = []
        for f in features:
            if f.accessibility and f.accessibility.collision_risk == "inaccessible":
                inaccessible.append(f.feature_id)
            elif f.type == "undercut_candidate":
                inaccessible.append(f.feature_id)
        return inaccessible

    def _generate_warnings(
        self,
        features: list[Feature],
        setups: list[Setup],
        operations: list[Operation],
        geometry: Any,
    ) -> list[str]:
        """Generate manufacturing warnings."""
        warnings = []

        if len(setups) > 1:
            warnings.append(f"Multiple setups ({len(setups)}) required - increases cost and alignment risk")

        inaccessible = self._identify_inaccessible(features, setups)
        if inaccessible:
            warnings.append(f"{len(inaccessible)} feature(s) may be inaccessible for 3-axis machining")

        # Check for thin walls
        thin_walls = [f for f in features if f.type == "thin_wall"]
        if thin_walls:
            warnings.append(f"{len(thin_walls)} thin wall feature(s) may require special fixturing")

        # Check for deep pockets
        for f in features:
            if f.type in ("rectangular_pocket", "circular_pocket", "complex_pocket"):
                if f.dimensions and f.dimensions.depth and f.dimensions.depth > 50:
                    warnings.append(f"Deep pocket {f.feature_id} (depth: {f.dimensions.depth}mm) may require extended tooling")

        # Check for small features
        small_holes = [f for f in features if f.type in ("through_hole", "blind_hole")
                      and f.dimensions and f.dimensions.diameter and f.dimensions.diameter < 2.0]
        if small_holes:
            warnings.append(f"{len(small_holes)} small hole(s) (<2mm) may require micro-tooling")

        if geometry and geometry.num_bodies > 1:
            warnings.append(f"Multi-body part ({geometry.num_bodies} bodies) - may require assembly or separate machining")

        return warnings


def estimate_cost(
    manufacturing_analysis: ManufacturingAnalysis,
    material: Any = None,
    region: str = "domestic",
    quantity: int = 1,
) -> CostEstimate:
    """
    Estimate manufacturing cost based on analysis results.
    Uses configurable rates - should come from machine/shop DB.
    """
    # Configurable rates (USD/hour unless noted)
    machine_rate_per_hour = 75.0  # CNC machine rate
    labor_rate_per_hour = 50.0    # Operator labor rate
    setup_rate_per_hour = 60.0    # Setup rate
    inspection_rate_per_hour = 45.0  # Inspection rate

    # Material cost
    material_cost = 0.0
    if material and hasattr(material, 'density_kg_m3') and manufacturing_analysis.stock_volume_cm3:
        volume_m3 = manufacturing_analysis.stock_volume_cm3 / 1_000_000.0
        mass_kg = volume_m3 * material.density_kg_m3
        material_cost = mass_kg * 5.0  # $5/kg indicative for aluminum

    # Machining cost
    machining_hours = manufacturing_analysis.total_cutting_time_min / 60.0
    machining_cost = machining_hours * machine_rate_per_hour

    # Setup cost
    setup_hours = manufacturing_analysis.total_setup_time_min / 60.0
    setup_cost = setup_hours * setup_rate_per_hour

    # Tooling cost (estimate based on operation count)
    tooling_cost = len(manufacturing_analysis.operations) * 5.0  # $5 per tool use

    # Inspection cost
    inspection_hours = manufacturing_analysis.total_inspection_time_min / 60.0
    inspection_cost = inspection_hours * inspection_rate_per_hour

    # Overhead (20% of machining + setup)
    overhead_cost = (machining_cost + setup_cost) * 0.20

    total_cost = (material_cost + machining_cost + setup_cost +
                  tooling_cost + inspection_cost + overhead_cost)

    # Assumptions
    assumptions = [
        f"Machine rate: ${machine_rate_per_hour}/hr",
        f"Labor rate: ${labor_rate_per_hour}/hr",
        f"Setup rate: ${setup_rate_per_hour}/hr",
        f"Material: indicative pricing for {region}",
        "No rush fees or shipping included",
        "Quantity: 1 unit (no volume discount)",
    ]

    return CostEstimate(
        material_cost=round(material_cost, 2),
        machining_cost=round(machining_cost, 2),
        setup_cost=round(setup_cost, 2),
        tooling_cost=round(tooling_cost, 2),
        inspection_cost=round(inspection_cost, 2),
        overhead_cost=round(overhead_cost, 2),
        total_cost=round(total_cost, 2),
        currency="USD",
        confidence=0.7,
        assumptions=assumptions,
        pricing_sources=["indicative_shop_rates"],
    )