"""CAD Processing Service - Geometry engine and feature recognition."""

import hashlib
import logging
import tempfile
import time
from pathlib import Path
from typing import Any
from uuid import UUID

from OCP.BRepCheck import BRepCheck_Analyzer
from OCP.BRepGProp import BRepGProp
from OCP.GProp import GProp_GProps
from OCP.IFSelect import IFSelect_ReturnStatus
from OCP.STEPControl import STEPControl_Reader, STEPControl_Writer, STEPControl_AsIs
from OCP.TopAbs import (
    TopAbs_COMPOUND,
    TopAbs_COMPSOLID,
    TopAbs_EDGE,
    TopAbs_FACE,
    TopAbs_SHELL,
    TopAbs_SOLID,
    TopAbs_VERTEX,
    TopAbs_WIRE,
)
from OCP.TopExp import TopExp_Explorer
from OCP.TopoDS import TopoDS_Shape, TopoDS

from app.core.config import get_settings
from app.schemas.cad_specs import (
    BoundingBox3D,
    CADSpecs,
    Feature,
    FeatureAccessibility,
    FeatureDimensions,
    FeatureRelationship,
    FeatureType,
    GeometrySummary,
    Plane3D,
    SolidBody,
    SourceFile,
    UnitsInfo,
    Vector3D,
    WarningItem,
    DetectionMethod,
    DepthType,
)
from app.services.feature_recognition import recognize_features
from app.services.geometry_utils import (
    classify_face,
    extract_face_loops,
    get_face_surface_type,
    get_shape_bounding_box,
    get_shape_volume_properties,
    identify_units,
    is_cylindrical_hole,
    is_planar_face,
    is_toroidal_face,
)

settings = get_settings()
logger = logging.getLogger(__name__)


class CADService:
    """Service for CAD file processing and feature recognition."""

    def __init__(self) -> None:
        self.settings = settings

    def import_step(self, file_path: Path) -> TopoDS_Shape:
        """Import STEP file and return the shape."""
        reader = STEPControl_Reader()
        status = reader.ReadFile(str(file_path))
        if status != IFSelect_ReturnStatus.IFSelect_RetDone:
            raise ValueError(f"Failed to read STEP file: {file_path} (status: {status})")

        reader.TransferRoots()
        shape = reader.OneShape()

        if shape.IsNull():
            raise ValueError("STEP file contains no valid geometry")

        logger.info(f"Imported STEP file: {file_path}, shape type: {shape.ShapeType()}")
        return shape

    def validate_geometry(self, shape: TopoDS_Shape) -> list[str]:
        """Validate geometry and return list of issues."""
        analyzer = BRepCheck_Analyzer(shape)
        if not analyzer.IsValid():
            return ["Geometry validation failed: invalid topology"]
        return []

    def extract_geometry_summary(self, shape: TopoDS_Shape) -> GeometrySummary:
        """Extract global geometry properties."""
        # Bounding box
        bbox = get_shape_bounding_box(shape)

        # Volume properties
        volume_props = get_shape_volume_properties(shape)
        volume = volume_props.Mass()
        center_of_mass = Vector3D(
            x=volume_props.CentreOfMass().X(),
            y=volume_props.CentreOfMass().Y(),
            z=volume_props.CentreOfMass().Z(),
        )

        # Surface area
        surface_props = GProp_GProps()
        BRepGProp.SurfaceProperties_s(shape, surface_props)
        surface_area = surface_props.Mass()

        # Count topology
        num_solids = 0
        num_shells = 0
        num_faces = 0
        num_edges = 0
        num_vertices = 0

        exp = TopExp_Explorer(shape, TopAbs_SOLID)
        while exp.More():
            num_solids += 1
            exp.Next()

        exp.Init(shape, TopAbs_SHELL)
        while exp.More():
            num_shells += 1
            exp.Next()

        exp.Init(shape, TopAbs_FACE)
        face_ids = []
        while exp.More():
            TopoDS.Face(exp.Current())
            num_faces += 1
            exp.Next()

        exp.Init(shape, TopAbs_EDGE)
        while exp.More():
            TopoDS.Edge(exp.Current())
            num_edges += 1
            exp.Next()

        exp.Init(shape, TopAbs_VERTEX)
        while exp.More():
            num_vertices += 1
            exp.Next()

        # Principal axes (simplified - would need proper inertia tensor)
        principal_axes = [
            Vector3D(x=1.0, y=0.0, z=0.0),
            Vector3D(x=0.0, y=1.0, z=0.0),
            Vector3D(x=0.0, y=0.0, z=1.0),
        ]

        return GeometrySummary(
            num_bodies=num_solids,
            num_shells=num_shells,
            num_faces=num_faces,
            num_edges=num_edges,
            num_vertices=num_vertices,
            volume=volume,
            surface_area=surface_area,
            bbox=bbox,
            center_of_mass=center_of_mass,
            principal_axes=principal_axes,
            symmetry={},
        )

    def extract_solid_bodies(self, shape: TopoDS_Shape) -> list[SolidBody]:
        """Extract individual solid bodies."""
        bodies = []

        exp = TopExp_Explorer(shape, TopAbs_SOLID)
        body_index = 0
        while exp.More():
            solid = exp.Current()
            body_id = f"body_{body_index}"

            # Volume properties
            vol_props = GProp_GProps()
            BRepGProp.VolumeProperties_s(solid, vol_props)
            volume = vol_props.Mass()
            com = Vector3D(
                x=vol_props.CentreOfMass().X(),
                y=vol_props.CentreOfMass().Y(),
                z=vol_props.CentreOfMass().Z(),
            )

            # Surface area
            surf_props = GProp_GProps()
            BRepGProp.SurfaceProperties_s(solid, surf_props)
            surface_area = surf_props.Mass()

            # Bounding box
            bbox = get_shape_bounding_box(solid)

            # Count topology for this body
            num_faces = 0
            num_edges = 0
            num_vertices = 0

            face_exp = TopExp_Explorer(solid, TopAbs_FACE)
            while face_exp.More():
                num_faces += 1
                face_exp.Next()

            edge_exp = TopExp_Explorer(solid, TopAbs_EDGE)
            while edge_exp.More():
                num_edges += 1
                edge_exp.Next()

            vert_exp = TopExp_Explorer(solid, TopAbs_VERTEX)
            while vert_exp.More():
                num_vertices += 1
                vert_exp.Next()

            # Validate
            analyzer = BRepCheck_Analyzer(solid)
            is_valid = analyzer.IsValid()
            validation_errors = [] if is_valid else ["Invalid topology"]

            bodies.append(SolidBody(
                body_id=body_id,
                volume=volume,
                surface_area=surface_area,
                bbox=bbox,
                center_of_mass=com,
                num_faces=num_faces,
                num_edges=num_edges,
                num_vertices=num_vertices,
                is_valid=is_valid,
                validation_errors=validation_errors,
            ))

            body_index += 1
            exp.Next()

        return bodies

    def recognize_features(self, shape: TopoDS_Shape, units_info: UnitsInfo) -> tuple[list[Feature], list[FeatureRelationship], list[WarningItem]]:
        """Recognize manufacturing features from shape using the feature recognition engine."""
        return recognize_features(shape, units_info)

    def generate_views(self, shape: TopoDS_Shape, output_dir: Path) -> dict[str, Path]:
        """Generate orthographic and isometric views."""
        # This would use OCCT's projection algorithms
        # For now, return placeholder
        views = {}
        view_names = ["top", "front", "right", "isometric"]
        for name in view_names:
            views[name] = output_dir / f"{name}.svg"
        return views

    def export_gltf(self, shape: TopoDS_Shape, output_path: Path) -> None:
        """Export shape to glTF for web viewing."""
        # Would use pygltflib or similar
        pass

    def compute_file_hash(self, file_path: Path) -> str:
        """Compute SHA256 hash of file."""
        sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha256.update(chunk)
        return sha256.hexdigest()

    def process_cad_file(self, file_path: Path, project_id: UUID) -> CADSpecs:
        """Main processing pipeline for a CAD file."""
        start_time = time.time()

        # Import
        shape = self.import_step(file_path)

        # Validate
        validation_errors = self.validate_geometry(shape)
        warnings = [WarningItem(code="validation", message=err, severity="warning", category="geometry")
                   for err in validation_errors]

        # Extract geometry
        geometry_summary = self.extract_geometry_summary(shape)
        solid_bodies = self.extract_solid_bodies(shape)

        # Identify units
        units_info = identify_units(shape)

        # Recognize features
        features, relationships, feature_warnings = self.recognize_features(shape, units_info)
        warnings.extend(feature_warnings)

        # Source file info
        source_file = SourceFile(
            role="model_3d",
            path=str(file_path),
            format="STEP",
            size_bytes=file_path.stat().st_size,
            sha256=self.compute_file_hash(file_path),
        )

        processing_time = time.time() - start_time

        return CADSpecs(
            job_id=str(project_id),
            source_files=[source_file],
            units=units_info,
            geometry_summary=geometry_summary,
            solid_bodies=solid_bodies,
            features=features,
            feature_relationships=relationships,
            warnings=warnings,
            processing_time_seconds=processing_time,
        )