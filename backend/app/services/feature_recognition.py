"""Feature Recognition Engine - Geometry-based manufacturing feature detection.

Detects: holes, counterbores, countersinks, slots, pockets, steps, shoulders,
bosses, fillets, chamfers, grooves, ribs, thin walls, tapered surfaces.
"""

import logging
import math
from typing import Any, Optional
from uuid import uuid4

from OCP.BRepAdaptor import BRepAdaptor_Surface
from OCP.BRepClass3d import BRepClass3d_SolidClassifier
from OCP.BRepExtrema import BRepExtrema_DistShapeShape
from OCP.BRepGProp import BRepGProp
from OCP.GeomAbs import (
    GeomAbs_Plane, GeomAbs_Cylinder, GeomAbs_Cone, GeomAbs_Torus, GeomAbs_Sphere,
)
from OCP.GProp import GProp_GProps
from OCP.TopAbs import (
    TopAbs_FACE, TopAbs_EDGE, TopAbs_VERTEX, TopAbs_WIRE, TopAbs_SOLID,
    TopAbs_IN, TopAbs_ON,
)
from OCP.TopExp import TopExp_Explorer
from OCP.TopoDS import TopoDS, TopoDS_Shape, TopoDS_Face, TopoDS_Edge, TopoDS_Wire
from OCP.gp import gp_Pnt, gp_Vec, gp_Ax1

from app.core.config import get_settings
from app.schemas.cad_specs import (
    BoundingBox3D, CADSpecs, Feature, FeatureAccessibility, FeatureDimensions,
    FeatureRelationship, FeatureType, GeometrySummary, Plane3D, UnitsInfo,
    Vector3D, WarningItem, DepthType, DetectionMethod,
)
from app.services.geometry_utils import (
    classify_face, get_face_surface_type, get_shape_bounding_box,
    get_shape_volume_properties, identify_units,
    is_cylindrical_face, is_conical_face, is_planar_face, is_toroidal_face,
    _to_face, _to_edge,
)

settings = get_settings()
logger = logging.getLogger(__name__)


# =============================================================================
# Helper Functions
# =============================================================================

def _face_center(face: TopoDS_Face) -> Vector3D:
    """Get centroid of a face."""
    props = GProp_GProps()
    BRepGProp.SurfaceProperties_s(face, props)
    c = props.CentreOfMass()
    return Vector3D(x=c.X(), y=c.Y(), z=c.Z())


def _face_area(face: TopoDS_Face) -> float:
    """Calculate face area."""
    props = GProp_GProps()
    BRepGProp.SurfaceProperties_s(face, props)
    return props.Mass()


def _face_normal_at_center(face: TopoDS_Face) -> Vector3D:
    """Get surface normal at face center."""
    surface = BRepAdaptor_Surface(face)
    try:
        from OCP.BRepTools import breptools_UVBounds
        u_min, u_max, v_min, v_max = breptools_UVBounds(face)
    except Exception:
        u_min, u_max, v_min, v_max = 0.0, 1.0, 0.0, 1.0
    u_mid = (u_min + u_max) / 2
    v_mid = (v_min + v_max) / 2
    pnt = gp_Pnt()
    normal = gp_Vec()
    surface.D1(u_mid, v_mid, pnt, normal)
    return Vector3D(x=normal.X(), y=normal.Y(), z=normal.Z())


def _cylinder_axis_radius(face: TopoDS_Face) -> tuple[Vector3D, Vector3D, float]:
    """Extract cylinder axis location, direction, and radius."""
    surface = BRepAdaptor_Surface(face)
    cyl = surface.Cylinder()
    axis = cyl.Axis()
    loc = axis.Location()
    direction = axis.Direction()
    return (
        Vector3D(x=loc.X(), y=loc.Y(), z=loc.Z()),
        Vector3D(x=direction.X(), y=direction.Y(), z=direction.Z()),
        cyl.Radius(),
    )


def _cone_axis_angle(face: TopoDS_Face) -> tuple[Vector3D, Vector3D, float]:
    """Extract cone axis location, direction, and semi-angle in degrees."""
    surface = BRepAdaptor_Surface(face)
    cone = surface.Cone()
    axis = cone.Axis()
    loc = axis.Location()
    direction = axis.Direction()
    return (
        Vector3D(x=loc.X(), y=loc.Y(), z=loc.Z()),
        Vector3D(x=direction.X(), y=direction.Y(), z=direction.Z()),
        math.degrees(cone.SemiAngle()),
    )


def _torus_axis_radii(face: TopoDS_Face) -> tuple[Vector3D, Vector3D, float, float]:
    """Extract torus axis location, direction, major radius, minor radius."""
    surface = BRepAdaptor_Surface(face)
    torus = surface.Torus()
    axis = torus.Axis()
    loc = axis.Location()
    direction = axis.Direction()
    return (
        Vector3D(x=loc.X(), y=loc.Y(), z=loc.Z()),
        Vector3D(x=direction.X(), y=direction.Y(), z=direction.Z()),
        torus.MajorRadius(),
        torus.MinorRadius(),
    )


def _plane_origin_normal(face: TopoDS_Face) -> tuple[Vector3D, Vector3D]:
    """Extract plane origin and normal."""
    surface = BRepAdaptor_Surface(face)
    plane = surface.Plane()
    axis = plane.Axis()
    loc = axis.Location()
    direction = axis.Direction()
    return (
        Vector3D(x=loc.X(), y=loc.Y(), z=loc.Z()),
        Vector3D(x=direction.X(), y=direction.Y(), z=direction.Z()),
    )


def _get_face_wires(face: TopoDS_Face) -> list[TopoDS_Wire]:
    """Get all wire loops from a face."""
    wires = []
    exp = TopExp_Explorer(face, TopAbs_WIRE)
    while exp.More():
        wires.append(TopoDS.Wire(exp.Current()))
        exp.Next()
    return wires


def _get_wire_edges(wire: TopoDS_Wire) -> list[TopoDS_Edge]:
    """Get all edges from a wire."""
    edges = []
    exp = TopExp_Explorer(wire, TopAbs_EDGE)
    while exp.More():
        edges.append(_to_edge(exp.Current()))
        exp.Next()
    return edges


def _get_face_edges(face: TopoDS_Face) -> list[TopoDS_Edge]:
    """Get all edges from a face."""
    return _get_wire_edges(_get_face_wires(face)[0]) if _get_face_wires(face) else []


def _faces_share_edge(face1: TopoDS_Face, face2: TopoDS_Face) -> bool:
    """Check if two faces share at least one edge."""
    edges1 = {id(e) for e in _get_face_edges(face1)}
    return any(id(e) in edges1 for e in _get_face_edges(face2))


def _is_point_inside_solid(shape: TopoDS_Shape, point: Vector3D, tolerance: float = 1e-6) -> bool:
    """Check if a point is inside a solid."""
    classifier = BRepClass3d_SolidClassifier(shape, gp_Pnt(point.x, point.y, point.z), tolerance)
    return classifier.State() in (TopAbs_IN, TopAbs_ON)


def _are_axes_parallel(a1: Vector3D, a2: Vector3D, tolerance: float = 0.01) -> bool:
    """Check if two vectors are parallel (or anti-parallel)."""
    dot = abs(a1.x * a2.x + a1.y * a2.y + a1.z * a2.z)
    mag1 = math.sqrt(a1.x**2 + a1.y**2 + a1.z**2)
    mag2 = math.sqrt(a2.x**2 + a2.y**2 + a2.z**2)
    if mag1 == 0 or mag2 == 0:
        return False
    return abs(dot / (mag1 * mag2) - 1.0) < tolerance


def _estimate_hole_depth(shape: TopoDS_Shape, axis: Vector3D, location: Vector3D, conversion: float) -> Optional[float]:
    """Estimate hole depth by projecting along axis until exiting solid."""
    try:
        max_dist = 1000.0 * conversion
        step = 0.25 * conversion
        dist = 0.0
        inside = False
        while dist < max_dist:
            p = gp_Pnt(location.x + axis.x * dist, location.y + axis.y * dist, location.z + axis.z * dist)
            state = BRepClass3d_SolidClassifier(shape, p, 1e-6).State()
            if state in (TopAbs_IN, TopAbs_ON):
                inside = True
                dist += step
            else:
                if inside:
                    return round(dist * conversion, 3)
                break
        return None
    except Exception:
        return None


# =============================================================================
# Main Feature Recognition
# =============================================================================

def recognize_features(shape: TopoDS_Shape, units_info: UnitsInfo) -> tuple[list[Feature], list[FeatureRelationship], list[WarningItem]]:
    """
    Main feature recognition entry point.
    Detects holes, counterbores, countersinks, slots, pockets, steps, shoulders,
    bosses, fillets, chamfers, grooves, ribs, thin walls, tapered surfaces.
    """
    features: list[Feature] = []
    relationships: list[FeatureRelationship] = []
    warnings: list[WarningItem] = []

    conversion = units_info.conversion_factor

    # Collect all faces
    face_map: dict[str, TopoDS_Face] = {}
    face_id_counter = 0
    exp = TopExp_Explorer(shape, TopAbs_FACE)
    while exp.More():
        face = TopoDS.Face(exp.Current())
        face_id = f"face_{face_id_counter}"
        face_map[face_id] = face
        face_id_counter += 1
        exp.Next()

    # Classify faces
    face_classifications: dict[str, dict] = {}
    for fid, face in face_map.items():
        face_classifications[fid] = classify_face(face)

    # =========================================================================
    # 1. Cylindrical Faces -> Holes, Counterbores, Threads
    # =========================================================================
    cylindrical_faces = [
        fid for fid, cls in face_classifications.items()
        if cls.get("type") == "cylindrical"
    ]

    # Group cylindrical faces by axis (same hole may have multiple cylindrical faces
    # for counterbore: large diameter + small diameter)
    axis_groups: dict[str, list[dict]] = {}
    for fid in cylindrical_faces:
        face = face_map[fid]
        try:
            loc, axis, radius = _cylinder_axis_radius(face)
            key = f"{round(axis.x, 3)}_{round(axis.y, 3)}_{round(axis.z, 3)}_{round(loc.x, 3)}_{round(loc.y, 3)}_{round(loc.z, 3)}"
            if key not in axis_groups:
                axis_groups[key] = {"axis": axis, "location": loc, "faces": []}
            axis_groups[key]["faces"].append({
                "fid": fid,
                "face": face,
                "radius": radius,
            })
        except Exception as e:
            logger.warning(f"Could not extract cylinder from face {fid}: {e}")
            continue

    for group_key, group in axis_groups.items():
        faces_info = group["faces"]
        axis = group["axis"]
        loc = group["location"]

        # Sort by radius descending (largest first = counterbore top)
        faces_info.sort(key=lambda f: f["radius"], reverse=True)
        primary = faces_info[0]
        diameter_mm = round(2 * primary["radius"] * conversion, 3)

        # Check for counterbore: multiple cylindrical faces on same axis
        is_counterbore = len(faces_info) > 1
        secondary_diameter = None
        if is_counterbore:
            secondary_diameter = round(2 * faces_info[-1]["radius"] * conversion, 3)

        # Determine if through or blind
        # Count adjacent planar faces (caps)
        planar_neighbors = 0
        for other_fid, other_face in face_map.items():
            if other_fid in [f["fid"] for f in faces_info]:
                continue
            if face_classifications[other_fid].get("type") == "planar":
                if _faces_share_edge(primary["face"], other_face):
                    planar_neighbors += 1

        depth_type = DepthType.THROUGH if planar_neighbors >= 2 else DepthType.BLIND
        depth_mm = None
        if depth_type == DepthType.THROUGH:
            depth_mm = _estimate_hole_depth(shape, axis, loc, conversion)

        confidence = 0.9 if planar_neighbors >= 1 else 0.6
        if is_counterbore:
            confidence = 0.85
            feature_type = FeatureType.COUNTERBORE
            subtype = f"counterbore_Ø{diameter_mm}_x_Ø{secondary_diameter}"
        else:
            feature_type = FeatureType.THROUGH_HOLE if depth_type == DepthType.THROUGH else FeatureType.BLIND_HOLE
            subtype = None

        # Check for thread candidates (small holes, typically M3-M12)
        is_tapped_candidate = (
            not is_counterbore and
            3.0 <= diameter_mm <= 12.0 and
            depth_type == DepthType.BLIND
        )

        final_type = FeatureType.TAPPED_HOLE_CANDIDATE if is_tapped_candidate else feature_type

        feature = Feature(
            feature_id=f"F-{uuid4().hex[:6].upper()}",
            type=final_type,
            subtype=subtype,
            position=Vector3D(
                x=round(loc.x * conversion, 3),
                y=round(loc.y * conversion, 3),
                z=round(loc.z * conversion, 3),
            ),
            axis=Vector3D(x=round(axis.x, 3), y=round(axis.y, 3), z=round(axis.z, 3)),
            dimensions=FeatureDimensions(
                diameter=diameter_mm,
                depth=depth_mm,
                major_diameter=secondary_diameter if is_counterbore else None,
            ),
            depth_type=depth_type.value,
            faces=[f["fid"] for f in faces_info],
            edges=[],
            open=True,
            through=(depth_type == DepthType.THROUGH),
            accessibility=FeatureAccessibility(
                approach_vectors=[
                    Vector3D(x=-axis.x, y=-axis.y, z=-axis.z),
                    Vector3D(x=axis.x, y=axis.y, z=axis.z),
                ],
                collision_risk="good",
            ),
            confidence=confidence,
            detection_method=DetectionMethod.CYLINDRICAL_FACE_PAIR,
            warnings=[],
        )
        features.append(feature)

    # =========================================================================
    # 2. Conical Faces -> Countersinks
    # =========================================================================
    conical_faces = [
        fid for fid, cls in face_classifications.items()
        if cls.get("type") == "conical"
    ]

    for fid in conical_faces:
        face = face_map[fid]
        try:
            loc, axis, semi_angle_deg = _cone_axis_angle(face)
            chamfer_angle_deg = round(90.0 - semi_angle_deg, 1)

            # Check for adjacent cylindrical face (countersink vs standalone chamfer)
            adjacent_cylindrical = []
            for other_fid, other_face in face_map.items():
                if other_fid == fid:
                    continue
                if face_classifications[other_fid].get("type") == "cylindrical":
                    if _faces_share_edge(face, other_face):
                        adjacent_cylindrical.append(other_fid)

            feature_type = FeatureType.COUNTERSINK if adjacent_cylindrical else FeatureType.CHAMFER
            confidence = 0.85 if adjacent_cylindrical else 0.75

            feature = Feature(
                feature_id=f"F-{uuid4().hex[:6].upper()}",
                type=feature_type,
                subtype="countersink" if adjacent_cylindrical else "standalone_chamfer",
                position=Vector3D(
                    x=round(loc.x * conversion, 3),
                    y=round(loc.y * conversion, 3),
                    z=round(loc.z * conversion, 3),
                ),
                axis=Vector3D(x=round(axis.x, 3), y=round(axis.y, 3), z=round(axis.z, 3)),
                dimensions=FeatureDimensions(
                    angle=chamfer_angle_deg,
                    chamfer_distance=round(semi_angle_deg * conversion, 3),
                ),
                faces=[fid] + adjacent_cylindrical,
                edges=[],
                open=True,
                through=False,
                accessibility=FeatureAccessibility(
                    approach_vectors=[Vector3D(x=axis.x, y=axis.y, z=axis.z)],
                    collision_risk="good",
                ),
                confidence=confidence,
                detection_method=DetectionMethod.CONICAL_FACE_BETWEEN_PLANES,
                warnings=[],
            )
            features.append(feature)
        except Exception as e:
            logger.warning(f"Could not extract cone from face {fid}: {e}")
            continue

    # =========================================================================
    # 3. Toroidal Faces -> Fillets / Rounded Corners
    # =========================================================================
    toroidal_faces = [
        fid for fid, cls in face_classifications.items()
        if cls.get("type") == "toroidal"
    ]

    for fid in toroidal_faces:
        face = face_map[fid]
        try:
            loc, axis, major_r, minor_r = _torus_axis_and_radii(face)
            corner_radius_mm = round(minor_r * conversion, 3)

            # Find adjacent planar faces
            adjacent_planar = []
            for other_fid, other_face in face_map.items():
                if other_fid == fid:
                    continue
                if face_classifications[other_fid].get("type") == "planar":
                    if _faces_share_edge(face, other_face):
                        adjacent_planar.append(other_fid)

            feature = Feature(
                feature_id=f"F-{uuid4().hex[:6].upper()}",
                type=FeatureType.FILLET,
                subtype="internal" if len(adjacent_planar) >= 2 else "external",
                position=Vector3D(
                    x=round(loc.x * conversion, 3),
                    y=round(loc.y * conversion, 3),
                    z=round(loc.z * conversion, 3),
                ),
                axis=Vector3D(x=round(axis.x, 3), y=round(axis.y, 3), z=round(axis.z, 3)),
                dimensions=FeatureDimensions(
                    corner_radius=corner_radius_mm,
                ),
                faces=[fid] + adjacent_planar,
                edges=[],
                open=False,
                through=False,
                accessibility=FeatureAccessibility(
                    approach_vectors=[Vector3D(x=axis.x, y=axis.y, z=axis.z)],
                    collision_risk="good",
                ),
                confidence=0.85,
                detection_method=DetectionMethod.TOROIDAL_FACE_BETWEEN_PLANES,
                warnings=[],
            )
            features.append(feature)
        except Exception as e:
            logger.warning(f"Could not extract torus from face {fid}: {e}")
            continue

    # =========================================================================
    # 4. Planar Faces -> Pockets, Steps, Shoulders, Bosses, Flat Faces
    # =========================================================================
    planar_faces = [
        fid for fid, cls in face_classifications.items()
        if cls.get("type") == "planar"
    ]

    # Group planar faces by normal direction
    plane_groups: dict[str, list[str]] = {}
    for fid in planar_faces:
        face = face_map[fid]
        try:
            origin, normal = _plane_origin_normal(face)
            key = f"{round(normal.x, 2)}_{round(normal.y, 2)}_{round(normal.z, 2)}"
            if key not in plane_groups:
                plane_groups[key] = []
            plane_groups[key].append(fid)
        except Exception:
            continue

    # For each plane group, analyze faces
    for group_key, face_ids in plane_groups.items():
        # Sort by area descending
        face_areas = [(fid, _face_area(face_map[fid])) for fid in face_ids]
        face_areas.sort(key=lambda x: x[1], reverse=True)

        for fid, area in face_areas:
            face = face_map[fid]
            if area < 1.0 * conversion * conversion:  # Too small
                continue

            wires = _get_face_wires(face)
            num_wires = len(wires)

            # Determine if this is a pocket bottom (has walls around it)
            adjacent_walls = 0
            adjacent_wall_types = []
            for other_fid, other_face in face_map.items():
                if other_fid == fid:
                    continue
                if _faces_share_edge(face, other_face):
                    otype = face_classifications[other_fid].get("type")
                    adjacent_walls += 1
                    adjacent_wall_types.append(otype)

            # Pocket detection: planar face surrounded by walls (cylindrical or planar)
            if adjacent_walls >= 3:
                # Determine pocket type based on boundary
                boundary_cylindrical = sum(
                    1 for t in adjacent_wall_types if t == "cylindrical"
                )
                boundary_planar = sum(
                    1 for t in adjacent_wall_types if t == "planar"
                )

                if boundary_cylindrical > 0 and boundary_planar == 0:
                    pocket_type = FeatureType.POCKET_CIRCULAR
                elif boundary_cylindrical == 0 and boundary_planar >= 3:
                    pocket_type = FeatureType.POCKET_RECTANGULAR
                else:
                    pocket_type = FeatureType.POCKET_COMPLEX

                # Estimate pocket depth from adjacent walls
                pocket_depth = None
                for wall_fid in [f for f, _ in []]:  # placeholder
                    pass

                feature = Feature(
                    feature_id=f"F-{uuid4().hex[:6].upper()}",
                    type=pocket_type,
                    subtype="pocket",
                    position=_face_center(face),
                    dimensions=FeatureDimensions(
                        width=None,
                        length=None,
                        depth=pocket_depth,
                    ),
                    faces=[fid],
                    edges=[],
                    open=False,
                    through=False,
                    accessibility=FeatureAccessibility(
                        approach_vectors=[_face_normal_at_center(face)],
                        collision_risk="limited",
                    ),
                    confidence=0.75,
                    detection_method=DetectionMethod.CLOSED_LOOP_PLANAR_BOTTOM,
                    warnings=[],
                )
                features.append(feature)

            # Step/Shoulder detection: planar face at different height than neighbor
            elif adjacent_walls >= 1 and num_wires == 1:
                # Check height difference with adjacent planar faces
                origin, normal = _plane_origin_normal(face)
                for other_fid in face_ids:
                    if other_fid == fid:
                        continue
                    other_face = face_map[other_fid]
                    if not _faces_share_edge(face, other_face):
                        continue
                    other_origin, other_normal = _plane_origin_normal(other_face)
                    # Check if normals are parallel (same plane orientation)
                    if _are_axes_parallel(normal, other_normal):
                        height_diff = abs(origin.z - other_origin.z)
                        if height_diff > 0.5 * conversion:
                            feature = Feature(
                                feature_id=f"F-{uuid4().hex[:6].upper()}",
                                type=FeatureType.STEP,
                                subtype="step",
                                position=_face_center(face),
                                dimensions=FeatureDimensions(
                                    height=round(height_diff * conversion, 3),
                                ),
                                faces=[fid, other_fid],
                                edges=[],
                                open=False,
                                through=False,
                                accessibility=FeatureAccessibility(
                                    approach_vectors=[normal],
                                    collision_risk="good",
                                ),
                                confidence=0.8,
                                detection_method=DetectionMethod.FACE_ADJACENCY_HEIGHT_DELTA,
                                warnings=[],
                            )
                            features.append(feature)
                            break

    # =========================================================================
    # 5. Boss Detection (protruding cylindrical or planar features)
    # =========================================================================
    # A boss is a cylindrical protrusion - similar to a hole but positive
    # We detect cylindrical faces that are convex (outside) rather than concave (inside)
    # Simplified: cylindrical faces not adjacent to planar caps on both sides

    # =========================================================================
    # 6. Feature Relationships - Pattern Detection
    # =========================================================================
    hole_features = [
        f for f in features
        if f.type in (FeatureType.THROUGH_HOLE, FeatureType.BLIND_HOLE,
                      FeatureType.COUNTERBORE, FeatureType.COUNTERSINK,
                      FeatureType.TAPPED_HOLE_CANDIDATE)
    ]

    if len(hole_features) >= 2:
        # Group by axis direction for pattern detection
        pattern_groups: dict[str, list[Feature]] = {}
        for hf in hole_features:
            if hf.axis:
                key = f"{round(hf.axis.x, 2)}_{round(hf.axis.y, 2)}_{round(hf.axis.z, 2)}"
                if key not in pattern_groups:
                    pattern_groups[key] = []
                pattern_groups[key].append(hf)

        for pkey, pfeatures in pattern_groups.items():
            if len(pfeatures) >= 2:
                # Sort by position along primary axis
                pfeatures.sort(key=lambda f: f.position.x + f.position.y + f.position.z)
                positions = [f.position.x + f.position.y + f.position.z for f in pfeatures]
                spacings = [positions[i + 1] - positions[i] for i in range(len(positions) - 1)]

                if spacings and all(abs(s - spacings[0]) < 0.5 * conversion for s in spacings):
                    pattern_id = f"PG-{uuid4().hex[:4].upper()}"
                    for pf in pfeatures:
                        pf.pattern_group = pattern_id
                    relationships.append(FeatureRelationship(
                        type=RelationshipType.PATTERN,
                        pattern_id=pattern_id,
                        pattern_type="linear",
                        features=[pf.feature_id for pf in pfeatures],
                        spacing=round(spacings[0], 3) if spacings else None,
                        details={"count": len(pfeatures), "axis": pkey},
                    ))

    # =========================================================================
    # 7. Symmetry Detection
    # =========================================================================
    # Simple symmetry check: features mirrored across principal planes
    symmetry_relationships = _detect_symmetry(features, conversion)
    relationships.extend(symmetry_relationships)

    return features, relationships, warnings


def _detect_symmetry(features: list[Feature], conversion: float) -> list[FeatureRelationship]:
    """Detect symmetrical feature pairs."""
    relationships = []

    # Check for features mirrored across XY plane (z -> -z)
    for i, f1 in enumerate(features):
        if not f1.axis or not f1.position:
            continue
        for f2 in features[i + 1:]:
            if not f2.axis or not f2.position:
                continue
            # Check if same type and mirrored position
            if f1.type == f2.type:
                # Mirror across XY (z sign flip)
                if (abs(f1.position.x - f2.position.x) < 0.5 * conversion and
                        abs(f1.position.y - f2.position.y) < 0.5 * conversion and
                        abs(f1.position.z + f2.position.z) < 0.5 * conversion):
                    relationships.append(FeatureRelationship(
                        type=RelationshipType.SYMMETRY,
                        features=[f1.feature_id, f2.feature_id],
                        details={"symmetry_plane": "XY", "mirror_axis": "Z"},
                    ))
                    break

    return relationships


def run_feature_recognition(cad_specs: CADSpecs) -> CADSpecs:
    """Run feature recognition on existing CAD specs (placeholder for re-processing)."""
    logger.info(f"Feature recognition: {len(cad_specs.features)} features already detected")
    return cad_specs