"""Topology- and analytic-surface based feature recognition.

The recognizer intentionally does not infer a hole merely because a cylindrical
face exists.  It combines the analytic surface, the face's neighbours, the
axis span, and the material side of the face.  Every result carries evidence
and a stable ID so a human review can be persisted without changing the raw
 detection.
"""

from __future__ import annotations

import hashlib
import math
from collections import defaultdict
from typing import Any

try:  # OCP is the supported OCCT Python binding for build123d 0.13.
    from OCP.Bnd import Bnd_Box
    from OCP.BRep import BRep_Tool
    from OCP.BRepAdaptor import BRepAdaptor_Surface
    from OCP.BRepBndLib import BRepBndLib
    from OCP.BRepClass3d import BRepClass3d_SolidClassifier
    from OCP.BRepGProp import BRepGProp
    from OCP.GeomAbs import GeomAbs_SurfaceType
    from OCP.gp import gp_Pnt
    from OCP.GProp import GProp_GProps
    from OCP.TopAbs import (
        TopAbs_EDGE,
        TopAbs_FACE,
        TopAbs_IN,
        TopAbs_ON,
        TopAbs_OUT,
        TopAbs_SHELL,
        TopAbs_SOLID,
        TopAbs_VERTEX,
    )
    from OCP.TopExp import TopExp_Explorer
    from OCP.TopoDS import TopoDS
except Exception:  # pragma: no cover - exercised only on unsupported installs
    BRep_Tool = BRepAdaptor_Surface = BRepBndLib = BRepClass3d_SolidClassifier = None
    BRepGProp = Bnd_Box = GeomAbs_SurfaceType = GProp_GProps = None
    TopExp_Explorer = TopoDS = None


_GEOM_AVAILABLE = BRepAdaptor_Surface is not None


def _round(value: float, digits: int = 3) -> float:
    return round(float(value), digits)


def _vec(x: float, y: float, z: float) -> dict[str, float]:
    return {"x": _round(x), "y": _round(y), "z": _round(z)}


def _bbox(shape: Any) -> tuple[dict[str, float], dict[str, float]]:
    if not _GEOM_AVAILABLE:
        return (_vec(0, 0, 0), _vec(0, 0, 0))
    box = Bnd_Box()
    BRepBndLib.Add_s(shape, box)
    low = box.CornerMin()
    high = box.CornerMax()
    return _vec(low.X(), low.Y(), low.Z()), _vec(high.X(), high.Y(), high.Z())


def _face_bbox(face: Any) -> tuple[dict[str, float], dict[str, float]]:
    return _bbox(face)


def _area(face: Any) -> float:
    props = GProp_GProps()
    BRepGProp.SurfaceProperties_s(face, props)
    return float(props.Mass())


def _centroid(face: Any) -> tuple[float, float, float]:
    props = GProp_GProps()
    BRepGProp.SurfaceProperties_s(face, props)
    point = props.CentreOfMass()
    return point.X(), point.Y(), point.Z()


def _normalise_axis(direction: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = direction
    length = math.sqrt(x * x + y * y + z * z) or 1.0
    x, y, z = x / length, y / length, z / length
    # Canonical sign makes opposite orientations part of the same axis group.
    for component in (x, y, z):
        if abs(component) > 1e-8:
            if component < 0:
                x, y, z = -x, -y, -z
            break
    return x, y, z


def _axis_key(direction: tuple[float, float, float], location: tuple[float, float, float]) -> str:
    dx, dy, dz = _normalise_axis(direction)
    dot = dx * location[0] + dy * location[1] + dz * location[2]
    px = location[0] - dx * dot
    py = location[1] - dy * dot
    pz = location[2] - dz * dot
    return f"{dx:.4f},{dy:.4f},{dz:.4f}|{px:.3f},{py:.3f},{pz:.3f}"


def _projection(value: tuple[float, float, float], axis: tuple[float, float, float]) -> float:
    return value[0] * axis[0] + value[1] * axis[1] + value[2] * axis[2]


def _bbox_corners(
    low: dict[str, float], high: dict[str, float]
) -> list[tuple[float, float, float]]:
    return [
        (low["x"], low["y"], low["z"]),
        (high["x"], low["y"], low["z"]),
        (low["x"], high["y"], low["z"]),
        (high["x"], high["y"], low["z"]),
        (low["x"], low["y"], high["z"]),
        (high["x"], low["y"], high["z"]),
        (low["x"], high["y"], high["z"]),
        (high["x"], high["y"], high["z"]),
    ]


def _face_surface(face: Any) -> dict[str, Any]:
    adaptor = BRepAdaptor_Surface(face)
    surface_type = adaptor.GetType()
    result: dict[str, Any] = {"type": "other", "surface_type": str(surface_type)}
    if surface_type == GeomAbs_SurfaceType.GeomAbs_Plane:
        plane = adaptor.Plane()
        axis = plane.Axis()
        location = axis.Location()
        direction = axis.Direction()
        result.update(
            type="planar",
            origin=_vec(location.X(), location.Y(), location.Z()),
            normal=_vec(direction.X(), direction.Y(), direction.Z()),
        )
    elif surface_type == GeomAbs_SurfaceType.GeomAbs_Cylinder:
        cylinder = adaptor.Cylinder()
        axis = cylinder.Axis()
        location = axis.Location()
        direction = axis.Direction()
        result.update(
            type="cylindrical",
            axis=_vec(direction.X(), direction.Y(), direction.Z()),
            axis_location=_vec(location.X(), location.Y(), location.Z()),
            radius=float(cylinder.Radius()),
        )
    elif surface_type == GeomAbs_SurfaceType.GeomAbs_Cone:
        cone = adaptor.Cone()
        axis = cone.Axis()
        location = axis.Location()
        direction = axis.Direction()
        result.update(
            type="conical",
            axis=_vec(direction.X(), direction.Y(), direction.Z()),
            axis_location=_vec(location.X(), location.Y(), location.Z()),
            semi_angle_deg=math.degrees(float(cone.SemiAngle())),
            reference_radius=float(cone.RefRadius()),
        )
    elif surface_type == GeomAbs_SurfaceType.GeomAbs_Torus:
        torus = adaptor.Torus()
        axis = torus.Axis()
        location = axis.Location()
        direction = axis.Direction()
        result.update(
            type="toroidal",
            axis=_vec(direction.X(), direction.Y(), direction.Z()),
            axis_location=_vec(location.X(), location.Y(), location.Z()),
            major_radius=float(torus.MajorRadius()),
            minor_radius=float(torus.MinorRadius()),
        )
    elif surface_type == GeomAbs_SurfaceType.GeomAbs_Sphere:
        sphere = adaptor.Sphere()
        result.update(type="spherical", radius=float(sphere.Radius()))
    return result


def _face_edges(face: Any) -> list[Any]:
    edges: list[Any] = []
    if not _GEOM_AVAILABLE:
        return edges
    from OCP.TopAbs import TopAbs_EDGE, TopAbs_WIRE

    explorer = TopExp_Explorer(face, TopAbs_WIRE)
    while explorer.More():
        wire = TopoDS.Wire(explorer.Current())
        edge_explorer = TopExp_Explorer(wire, TopAbs_EDGE)
        while edge_explorer.More():
            edges.append(TopoDS.Edge(edge_explorer.Current()))
            edge_explorer.Next()
        explorer.Next()
    return edges


def _shares_edge(left: list[Any], right: list[Any]) -> bool:
    return any(a.IsSame(b) for a in left for b in right)


def _solid_side(shape: Any, point: tuple[float, float, float]) -> str:
    """Classify a point as in/out/on the material, when OCCT can do so."""

    if not _GEOM_AVAILABLE or BRepClass3d_SolidClassifier is None:
        return "unknown"
    try:
        classifier = BRepClass3d_SolidClassifier(shape, gp_Pnt(*point), 1e-6)
        state = classifier.State()
        if state == TopAbs_IN:
            return "in"
        if state == TopAbs_OUT:
            return "out"
        if state == TopAbs_ON:
            return "on"
    except Exception:
        pass
    return "unknown"


def _stable_id(feature_type: str, key: str) -> str:
    digest = hashlib.sha1(f"{feature_type}|{key}".encode()).hexdigest()[:10].upper()
    return f"F-{feature_type.upper().replace('_', '-')}-{digest}"


def _base_feature(
    feature_type: str,
    key: str,
    position: tuple[float, float, float],
    confidence: float,
    method: str,
    evidence: dict[str, Any],
    *,
    axis: tuple[float, float, float] | None = None,
    faces: list[str] | None = None,
    dimensions: dict[str, Any] | None = None,
    accessibility: str = "good",
    subtype: str | None = None,
    depth_type: str | None = None,
    through: bool = False,
) -> dict[str, Any]:
    feature: dict[str, Any] = {
        "feature_id": _stable_id(feature_type, key),
        "type": feature_type,
        "subtype": subtype,
        "position": _vec(*position),
        "axis": _vec(*axis) if axis else None,
        "dimensions": dimensions or {},
        "depth_type": depth_type,
        "through": through,
        "open": feature_type in {"through_hole", "blind_hole", "counterbore", "countersink"},
        "faces": faces or [],
        "edges": [],
        "confidence": max(0.0, min(1.0, confidence)),
        "detection_method": method,
        "evidence": evidence,
        "accessibility": {"collision_risk": accessibility, "notes": []},
        "review_state": "raw",
        "reviewed": False,
        "warnings": [],
        "source": "geometry",
    }
    return feature


def recognize_features(
    shape: Any, units_info: Any = "mm", conversion_factor: float | None = None
) -> dict[str, Any]:
    """Recognize supported manufacturing features from a STEP shape.

    Returns a real analysis payload with ``geometry_summary``, ``bodies``,
    ``faces``, ``raw_features``, ``units`` and ``warnings``.  ``units_info``
    may be the legacy object exposing ``conversion_factor``, a unit string, or
    a units dict (as produced by :func:`cad_service.detect_source_units`).
    Coordinates returned by OCCT are normalized to millimetres; the factor is
    accepted for API compatibility and recorded in evidence.
    """

    if not _GEOM_AVAILABLE:
        raise RuntimeError("OCP is required for STEP feature recognition")
    warnings: list[dict[str, Any]] = []
    if conversion_factor is None:
        if isinstance(units_info, dict):
            conversion_factor = float(units_info.get("conversion_factor", 1.0) or 1.0)
        else:
            conversion_factor = float(getattr(units_info, "conversion_factor", 1.0) or 1.0)
    units = (
        units_info
        if isinstance(units_info, dict)
        else {"source": str(units_info), "normalized": "mm", "conversion_factor": conversion_factor}
    )

    faces: list[dict[str, Any]] = []
    face_objects: list[Any] = []
    explorer = TopExp_Explorer(shape, TopAbs_FACE)
    while explorer.More():
        face = TopoDS.Face(explorer.Current())
        low, high = _face_bbox(face)
        info = _face_surface(face)
        info.update(
            face_id=f"face_{len(faces):04d}",
            area=_round(_area(face), 5),
            bbox={"min": low, "max": high},
            centroid=list(_centroid(face)),
        )
        faces.append(info)
        face_objects.append(face)
        explorer.Next()

    edge_lists = [_face_edges(face) for face in face_objects]
    adjacency: list[list[int]] = [[] for _ in faces]
    for i in range(len(faces)):
        for j in range(i + 1, len(faces)):
            if _shares_edge(edge_lists[i], edge_lists[j]):
                adjacency[i].append(j)
                adjacency[j].append(i)

    shape_low, shape_high = _bbox(shape)
    shape_size = {
        "x": shape_high["x"] - shape_low["x"],
        "y": shape_high["y"] - shape_low["y"],
        "z": shape_high["z"] - shape_low["z"],
    }
    features: list[dict[str, Any]] = []
    used_ids: set[str] = set()

    # Cylindrical surfaces are grouped by their *axis line*, not by radius or
    # face count.  This identifies coaxial counterbores and stepped bores.
    cylinder_groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for index, info in enumerate(faces):
        if info["type"] != "cylindrical":
            continue
        axis = tuple(info["axis"].values())
        location = tuple(info["axis_location"].values())
        key = _axis_key(axis, location)
        info = dict(info)
        info["index"] = index
        info["group_key"] = key
        info["axis_tuple"] = axis
        info["location_tuple"] = location
        cylinder_groups[key].append(info)

    for group_key, group in cylinder_groups.items():
        group.sort(key=lambda item: item["radius"], reverse=True)
        primary = group[0]
        axis = primary["axis_tuple"]
        location = primary["location_tuple"]
        radius = primary["radius"]
        # Face centre and radial direction are used to distinguish a void from
        # a boss by checking which side contains material.
        centre = tuple(primary["centroid"])
        radial = (centre[0] - location[0], centre[1] - location[1], centre[2] - location[2])
        radial_length = math.sqrt(sum(v * v for v in radial))
        if radial_length > 1e-8:
            radial = tuple(v / radial_length for v in radial)
            probe = (
                centre[0] - radial[0] * min(radius * 0.25, 0.25),
                centre[1] - radial[1] * min(radius * 0.25, 0.25),
                centre[2] - radial[2] * min(radius * 0.25, 0.25),
            )
        else:
            probe = centre
        side = _solid_side(shape, probe)
        # A cylinder whose inward side is outside the material is a hole.  A
        # boss has material on its inward side.  Fall back to adjacency when
        # the classifier cannot handle a compound shape.
        planar_neighbours = [j for j in adjacency[primary["index"]] if faces[j]["type"] == "planar"]
        is_hole = side == "out" or (side == "unknown" and bool(planar_neighbours))
        if not is_hole:
            continue

        projections: list[float] = []
        for item in group:
            low, high = item["bbox"]["min"], item["bbox"]["max"]
            projections.extend(_projection(corner, axis) for corner in _bbox_corners(low, high))
        span = max(projections) - min(projections)
        axis_extent = max(
            abs(shape_size["x"] * axis[0]),
            abs(shape_size["y"] * axis[1]),
            abs(shape_size["z"] * axis[2]),
        )
        through = bool(axis_extent and span >= axis_extent * 0.88)

        # Multiple coaxial cylinders are a counterbore candidate when the
        # larger radius is the outer portion and the smaller radius continues
        # below it.  A single cylinder is an ordinary hole.
        counterbore = False
        secondary_radius = None
        if len(group) > 1:
            secondary_radius = group[-1]["radius"]
            # Require a distinct radius and a radial step (not two duplicate
            # faces from a split seam).
            counterbore = abs(radius - secondary_radius) > max(1e-4, radius * 0.02)
        feature_type = (
            "counterbore" if counterbore else ("through_hole" if through else "blind_hole")
        )
        subtype = None
        dimensions: dict[str, Any] = {
            "diameter": _round(2.0 * radius * conversion_factor, 4),
            "depth": _round(span * conversion_factor, 4),
        }
        if counterbore and secondary_radius is not None:
            dimensions["major_diameter"] = _round(2.0 * radius * conversion_factor, 4)
            dimensions["secondary_diameter"] = _round(2.0 * secondary_radius * conversion_factor, 4)
            subtype = "coaxial_stepped_bore"
        position = tuple(primary["centroid"])
        evidence = {
            "surface": "cylinder",
            "axis_line": group_key,
            "radius_mm": _round(radius * conversion_factor, 4),
            "axial_span_mm": _round(span * conversion_factor, 4),
            "material_side": side,
            "adjacent_face_ids": [faces[j]["face_id"] for j in adjacency[primary["index"]]],
            "planar_neighbour_count": len(planar_neighbours),
            "analysis": "analytic cylinder plus material-side and adjacency checks",
        }
        feature = _base_feature(
            feature_type,
            group_key,
            position,
            0.92 if through else 0.82,
            "analytic_cylinder_with_adjacency",
            evidence,
            axis=axis,
            faces=[item["face_id"] for item in group],
            dimensions=dimensions,
            accessibility="good" if through else "limited",
            subtype=subtype,
            depth_type="through" if through else "blind",
            through=through,
        )
        if feature["feature_id"] not in used_ids:
            used_ids.add(feature["feature_id"])
            features.append(feature)

    planar_indices_for_size = [i for i, item in enumerate(faces) if item["type"] == "planar"]
    max_planar_area = max((faces[i]["area"] for i in planar_indices_for_size), default=0.0)

    # Cylindrical faces that are not bores can be rounded corners/fillets.
    # A fillet is evidenced by a cylindrical surface meeting at least two
    # non-parallel planar faces; this is distinct from a cylinder-count-only
    # hole heuristic.
    hole_face_ids: set[str] = set()
    for feature in features:
        if feature.get("type") in {"through_hole", "blind_hole", "counterbore", "countersink"}:
            hole_face_ids.update(feature.get("faces", []))
    for index, info in enumerate(faces):
        if info["type"] != "cylindrical" or info["face_id"] in hole_face_ids:
            continue
        planar_neighbours = [j for j in adjacency[index] if faces[j]["type"] == "planar"]
        if len(planar_neighbours) < 2:
            continue
        normals = [tuple(faces[j]["normal"].values()) for j in planar_neighbours]
        non_parallel = any(
            abs(sum(a * b for a, b in zip(normals[0], other))) < 0.95 for other in normals[1:]
        )
        if not non_parallel:
            continue
        axis = tuple(info["axis"].values())
        key = f"{info['face_id']}|{info['radius']:.4f}"
        feature = _base_feature(
            "fillet",
            key,
            tuple(info["centroid"]),
            0.76,
            "cylindrical_surface_between_nonparallel_planes",
            {
                "surface": "cylinder",
                "radius_mm": _round(info["radius"] * conversion_factor, 4),
                "adjacent_face_ids": [faces[j]["face_id"] for j in planar_neighbours],
                "analysis": "rounded corner evidenced by cylindrical surface and planar adjacency",
            },
            axis=axis,
            faces=[info["face_id"]] + [faces[j]["face_id"] for j in planar_neighbours],
            dimensions={"corner_radius": _round(info["radius"] * conversion_factor, 4)},
            accessibility="good",
        )
        if feature["feature_id"] not in used_ids:
            used_ids.add(feature["feature_id"])
            features.append(feature)

    # Narrow planar faces between non-parallel planes are chamfer evidence.
    # Large parallel faces are steps/shoulders and are handled separately.
    for index, info in enumerate(faces):
        if info["type"] != "planar":
            continue
        if max_planar_area and info["area"] > max_planar_area * 0.25:
            continue
        planar_neighbours = [j for j in adjacency[index] if faces[j]["type"] == "planar"]
        normal = tuple(info["normal"].values())
        # Axis-aligned narrow exterior walls are not chamfers.  A true
        # chamfer has an oblique normal (or is an interior transition).
        if max(abs(component) for component in normal) > 0.98:
            # A purely axis-aligned narrow face is an internal wall or an
            # exterior wall, not a chamfer transition.
            continue
        angled = [
            j
            for j in planar_neighbours
            if abs(sum(a * b for a, b in zip(normal, tuple(faces[j]["normal"].values())))) < 0.95
        ]
        if len(angled) < 2:
            continue
        key = f"{info['face_id']}|chamfer"
        feature = _base_feature(
            "chamfer",
            key,
            tuple(info["centroid"]),
            0.68,
            "narrow_planar_face_between_angled_planes",
            {
                "surface": "plane",
                "face_area_mm2": _round(info["area"] * conversion_factor * conversion_factor, 4),
                "adjacent_face_ids": [faces[j]["face_id"] for j in angled],
                "analysis": "narrow planar transition between non-parallel planes",
            },
            faces=[info["face_id"]] + [faces[j]["face_id"] for j in angled],
            dimensions={"chamfer_distance": _round(math.sqrt(info["area"]) * conversion_factor, 4)},
            accessibility="good",
        )
        if feature["feature_id"] not in used_ids:
            used_ids.add(feature["feature_id"])
            features.append(feature)

    # Conical faces adjacent to a cylindrical bore are countersink candidates.
    for index, info in enumerate(faces):
        if info["type"] != "conical":
            continue
        adjacent_cylinders = [j for j in adjacency[index] if faces[j]["type"] == "cylindrical"]
        adjacent_planes = [j for j in adjacency[index] if faces[j]["type"] == "planar"]
        axis = tuple(info["axis"].values())
        axis_location = tuple(info["axis_location"].values())
        cone_axis_key = _axis_key(axis, axis_location)
        coaxial_cylinders = [
            item
            for item in cylinder_groups.get(cone_axis_key, [])
            if item["face_id"] != info["face_id"]
        ]
        key = f"{info['face_id']}|{info['reference_radius']:.4f}"
        if adjacent_cylinders or coaxial_cylinders:
            feature_type = "countersink"
            confidence = 0.86 if adjacent_cylinders else 0.74
            method = "conical_surface_coaxial_with_cylinder"
        elif adjacent_planes:
            feature_type = "chamfer"
            confidence = 0.72
            method = "conical_surface_adjacent_to_plane"
        else:
            feature_type = "chamfer"
            confidence = 0.55
            method = "standalone_conical_surface"
        dimensions = {
            "angle": _round(90.0 - info["semi_angle_deg"], 3),
            "chamfer_distance": _round(info["reference_radius"] * conversion_factor, 4),
        }
        feature = _base_feature(
            feature_type,
            key,
            tuple(info["centroid"]),
            confidence,
            method,
            {
                "surface": "cone",
                "semi_angle_deg": _round(info["semi_angle_deg"], 4),
                "adjacent_face_ids": [faces[j]["face_id"] for j in adjacency[index]],
                "adjacent_cylinder_count": len(adjacent_cylinders),
            },
            axis=axis,
            faces=[info["face_id"]]
            + [faces[j]["face_id"] for j in adjacent_cylinders + adjacent_planes],
            dimensions=dimensions,
            accessibility="good",
        )
        if feature["feature_id"] not in used_ids:
            used_ids.add(feature["feature_id"])
            features.append(feature)

    # Toroidal faces are strong evidence for a fillet/rounded corner.
    for info in faces:
        if info["type"] != "toroidal":
            continue
        key = info["face_id"]
        feature = _base_feature(
            "fillet",
            key,
            tuple(info["centroid"]),
            0.82,
            "toroidal_surface_with_adjacency",
            {
                "surface": "torus",
                "minor_radius_mm": _round(info["minor_radius"] * conversion_factor, 4),
                "major_radius_mm": _round(info["major_radius"] * conversion_factor, 4),
                "adjacent_face_ids": [faces[j]["face_id"] for j in adjacency[faces.index(info)]],
            },
            axis=tuple(info["axis"].values()),
            faces=[info["face_id"]],
            dimensions={"corner_radius": _round(info["minor_radius"] * conversion_factor, 4)},
            accessibility="good",
        )
        if feature["feature_id"] not in used_ids:
            used_ids.add(feature["feature_id"])
            features.append(feature)

    # Planar faces with several adjacent walls are pocket/step evidence.  The
    # face area and inner-loop count distinguish a pocket bottom from an
    # external top face.
    planar_indices = [i for i, info in enumerate(faces) if info["type"] == "planar"]
    if planar_indices:
        max_planar_area = max(faces[i]["area"] for i in planar_indices)
    else:
        max_planar_area = 0.0
    for index in planar_indices:
        info = faces[index]
        neighbours = adjacency[index]
        planar_neighbours = [j for j in neighbours if faces[j]["type"] == "planar"]
        wall_neighbours = [
            j for j in neighbours if faces[j]["type"] in {"planar", "cylindrical", "conical"}
        ]
        # A recessed bottom is smaller than the main exterior plane and has
        # multiple walls.  Require at least three wall neighbours to avoid
        # calling an ordinary block face a pocket.
        if len(wall_neighbours) >= 3 and info["area"] < max_planar_area * 0.9:
            # A planar face on the outside boundary of the solid is an
            # exterior wall, not a pocket bottom.  Recessed bottoms lie at
            # an interior offset along their own normal.
            normal = tuple(info["normal"].values())
            offset = _projection(tuple(info["origin"].values()), normal)
            projections = [
                _projection(corner, normal) for corner in _bbox_corners(shape_low, shape_high)
            ]
            boundary_tolerance = max(0.05 * conversion_factor, 0.05)
            if (
                abs(offset - min(projections)) <= boundary_tolerance
                or abs(offset - max(projections)) <= boundary_tolerance
            ):
                continue
            # A pocket bottom has a larger parallel opening plane above it.
            # This excludes the vertical walls of a slot/pocket (which also
            # have several neighbours) and avoids counting ordinary blocks.
            parallel_opening = False
            for other_index in planar_indices:
                if other_index == index:
                    continue
                other = faces[other_index]
                other_normal = tuple(other["normal"].values())
                if abs(sum(a * b for a, b in zip(normal, other_normal))) < 0.99:
                    continue
                other_offset = _projection(tuple(other["origin"].values()), normal)
                if abs(other_offset - offset) <= boundary_tolerance:
                    continue
                if other["area"] > info["area"] * 1.15:
                    parallel_opening = True
                    break
            if not parallel_opening:
                continue
            # A pocket bottom is bounded by the recess walls, not by the
            # much larger exterior face that happens to be adjacent to one
            # of those walls.
            if any(faces[j]["area"] > info["area"] * 1.15 for j in neighbours):
                continue
            low, high = info["bbox"]["min"], info["bbox"]["max"]
            dx = high["x"] - low["x"]
            dy = high["y"] - low["y"]
            aspect = max(dx, dy) / max(min(dx, dy), 1e-6)
            feature_type = (
                "open_slot"
                if aspect >= 3.0
                else ("rectangular_pocket" if planar_neighbours else "complex_pocket")
            )
            key = f"{info['face_id']}|{low['x']:.3f},{low['y']:.3f},{low['z']:.3f}"
            feature = _base_feature(
                feature_type,
                key,
                tuple(info["centroid"]),
                0.70,
                "planar_bottom_adjacency",
                {
                    "surface": "plane",
                    "face_area_mm2": _round(
                        info["area"] * conversion_factor * conversion_factor, 4
                    ),
                    "adjacent_face_ids": [faces[j]["face_id"] for j in neighbours],
                    "wall_neighbour_count": len(wall_neighbours),
                    "aspect_ratio": _round(aspect, 3),
                },
                axis=tuple(info["normal"].values()),
                faces=[info["face_id"]],
                dimensions={
                    "width": _round(dx * conversion_factor, 4),
                    "length": _round(dy * conversion_factor, 4),
                },
                accessibility="limited",
                subtype="recess",
            )
            if feature["feature_id"] not in used_ids:
                used_ids.add(feature["feature_id"])
                features.append(feature)

    # Steps/shoulders are evidenced by two parallel planar faces at different
    # offsets.  This is deliberately conservative to avoid manufacturing a
    # step for every coplanar duplicate.
    for i, first in enumerate(planar_indices):
        first_info = faces[first]
        first_normal = tuple(first_info["normal"].values())
        first_axis = _normalise_axis(first_normal)
        first_offset = _projection(tuple(first_info["origin"].values()), first_axis)
        for second in planar_indices[i + 1 :]:
            second_info = faces[second]
            second_axis = _normalise_axis(tuple(second_info["normal"].values()))
            if sum(a * b for a, b in zip(first_axis, second_axis)) < 0.999:
                continue
            second_offset = _projection(tuple(second_info["origin"].values()), first_axis)
            if abs(second_offset - first_offset) <= max(0.25 * conversion_factor, 0.1):
                continue
            if not any(j in adjacency[first] for j in [second]) and not any(
                j in adjacency[second] for j in [first]
            ):
                continue
            key = f"{first_info['face_id']}|{second_info['face_id']}"
            feature = _base_feature(
                "step",
                key,
                tuple(first_info["centroid"]),
                0.68,
                "parallel_plane_offset_and_adjacency",
                {
                    "surface": "parallel_planes",
                    "offset_delta_mm": _round(
                        abs(second_offset - first_offset) * conversion_factor, 4
                    ),
                    "adjacent_face_ids": [first_info["face_id"], second_info["face_id"]],
                },
                axis=first_axis,
                faces=[first_info["face_id"], second_info["face_id"]],
                dimensions={
                    "height": _round(abs(second_offset - first_offset) * conversion_factor, 4)
                },
                accessibility="good",
                subtype="shoulder",
            )
            if feature["feature_id"] not in used_ids:
                used_ids.add(feature["feature_id"])
                features.append(feature)

    # --- Build the analysis payload ---------------------------------------
    def _count_topology(target: Any, kind: Any) -> int:
        count = 0
        explorer = TopExp_Explorer(target, kind)
        while explorer.More():
            count += 1
            explorer.Next()
        return count

    volume_props = GProp_GProps()
    BRepGProp.VolumeProperties_s(shape, volume_props)
    total_volume = float(volume_props.Mass())
    centre = volume_props.CentreOfMass()
    surface_area = sum(float(item["area"]) for item in faces)
    geometry_summary = {
        "num_bodies": _count_topology(shape, TopAbs_SOLID),
        "num_shells": _count_topology(shape, TopAbs_SHELL),
        "num_faces": len(faces),
        "num_edges": _count_topology(shape, TopAbs_EDGE),
        "num_vertices": _count_topology(shape, TopAbs_VERTEX),
        "volume": _round(total_volume),
        "surface_area": _round(surface_area),
        "bbox": {"min": shape_low, "max": shape_high},
        "center_of_mass": _vec(centre.X(), centre.Y(), centre.Z()),
    }

    bodies: list[dict[str, Any]] = []
    body_explorer = TopExp_Explorer(shape, TopAbs_SOLID)
    while body_explorer.More():
        solid = body_explorer.Current()
        bprops = GProp_GProps()
        BRepGProp.VolumeProperties_s(solid, bprops)
        bcentre = bprops.CentreOfMass()
        low, high = _bbox(solid)
        bodies.append(
            {
                "body_id": f"body_{len(bodies):03d}",
                "volume": _round(float(bprops.Mass())),
                "surface_area": _round(sum(float(item["area"]) for item in faces)),
                "bbox": {"min": low, "max": high},
                "center_of_mass": _vec(bcentre.X(), bcentre.Y(), bcentre.Z()),
                "num_faces": _count_topology(solid, TopAbs_FACE),
            }
        )
        body_explorer.Next()

    # Deduplicate by stable ID and by an equivalent geometric key.  A STEP
    # import can contain duplicate faces from a compound or seam.
    unique: dict[str, dict[str, Any]] = {}
    for feature in features:
        unique.setdefault(feature["feature_id"], feature)
    feature_list = list(unique.values())

    return {
        "units": units,
        "warnings": warnings,
        "geometry_summary": geometry_summary,
        "solid_bodies": bodies,
        "bodies": bodies,
        "faces": faces,
        "raw_features": feature_list,
        "features": feature_list,
    }


def run_feature_recognition(cad_specs: Any) -> Any:
    """Compatibility wrapper for the original scaffold."""

    if hasattr(cad_specs, "features"):
        cad_specs.features = (
            recognize_features(cad_specs.shape)
            if hasattr(cad_specs, "shape")
            else cad_specs.features
        )
    return cad_specs
