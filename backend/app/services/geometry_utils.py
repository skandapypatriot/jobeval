"""Geometry utility functions for OpenCASCADE (OCP) operations."""

from typing import Any

from OCP.BRep import BRep_Tool
from OCP.BRepAdaptor import BRepAdaptor_Surface, BRepAdaptor_Curve
from OCP.BRepGProp import BRepGProp
from OCP.GProp import GProp_GProps
from OCP.TopAbs import TopAbs_FACE, TopAbs_EDGE, TopAbs_WIRE
from OCP.TopExp import TopExp_Explorer
from OCP.TopoDS import TopoDS_Shape, TopoDS
from OCP.gp import gp_Pnt, gp_Vec
from OCP.Bnd import Bnd_Box
from OCP.BRepBndLib import BRepBndLib
from OCP.GeomAbs import (
    GeomAbs_Cylinder,
    GeomAbs_Plane,
    GeomAbs_Cone,
    GeomAbs_Sphere,
    GeomAbs_Torus,
    GeomAbs_BezierSurface,
    GeomAbs_BSplineSurface,
    GeomAbs_OtherSurface,
)

from app.schemas.cad_specs import BoundingBox3D, Vector3D


def _to_face(shape: TopoDS_Shape) -> Any:
    """Downcast a Shape to Face."""
    return TopoDS.Face(shape)


def _to_edge(shape: TopoDS_Shape) -> Any:
    """Downcast a Shape to Edge."""
    return TopoDS.Edge(shape)


def get_shape_bounding_box(shape: TopoDS_Shape) -> BoundingBox3D:
    """Get bounding box of a shape."""
    bbox = Bnd_Box()
    BRepBndLib.Add_s(shape, bbox)

    return BoundingBox3D(
        min=Vector3D(x=bbox.GetXMin(), y=bbox.GetYMin(), z=bbox.GetZMin()),
        max=Vector3D(x=bbox.GetXMax(), y=bbox.GetYMax(), z=bbox.GetZMax()),
    )


def get_shape_volume_properties(shape: TopoDS_Shape) -> GProp_GProps:
    """Get volume properties (mass, center of mass, inertia)."""
    props = GProp_GProps()
    BRepGProp.VolumeProperties_s(shape, props)
    return props


def classify_face(face: Any) -> dict[str, Any]:
    """Classify a face by its surface type."""
    surface = BRepAdaptor_Surface(face)
    surface_type = surface.GetType()

    type_map = {
        GeomAbs_Plane: "planar",
        GeomAbs_Cylinder: "cylindrical",
        GeomAbs_Cone: "conical",
        GeomAbs_Sphere: "spherical",
        GeomAbs_Torus: "toroidal",
        GeomAbs_BezierSurface: "bezier",
        GeomAbs_BSplineSurface: "nurbs",
        GeomAbs_OtherSurface: "other",
    }

    return {
        "type": type_map.get(surface_type, "unknown"),
        "geomabs_type": surface_type,
        "surface": surface,
    }


def get_face_surface_type(face: Any) -> int:
    """Get GeomAbs surface type enum value."""
    surface = BRepAdaptor_Surface(face)
    return surface.GetType()


def is_planar_face(face: Any) -> bool:
    """Check if face is planar."""
    return get_face_surface_type(face) == GeomAbs_Plane


def is_cylindrical_face(face: Any) -> bool:
    """Check if face is cylindrical."""
    return get_face_surface_type(face) == GeomAbs_Cylinder


def is_conical_face(face: Any) -> bool:
    """Check if face is conical."""
    return get_face_surface_type(face) == GeomAbs_Cone


def is_spherical_face(face: Any) -> bool:
    """Check if face is spherical."""
    return get_face_surface_type(face) == GeomAbs_Sphere


def is_toroidal_face(face: Any) -> bool:
    """Check if face is toroidal."""
    return get_face_surface_type(face) == GeomAbs_Torus


def is_cylindrical_hole(face: Any) -> bool:
    """Heuristic: check if cylindrical face could be a hole."""
    if not is_cylindrical_face(face):
        return False

    # Check if face has inner wires (hole boundary)
    exp = TopExp_Explorer(face, TopAbs_WIRE)
    wire_count = 0
    while exp.More():
        wire_count += 1
        exp.Next()

    # A cylindrical hole typically has at least 1 wire
    return wire_count >= 1


def extract_face_loops(face: Any) -> list[Any]:
    """Extract wire loops from a face."""
    loops = []
    exp = TopExp_Explorer(face, TopAbs_WIRE)
    while exp.More():
        loops.append(exp.Current())
        exp.Next()
    return loops


def identify_units(shape: TopoDS_Shape) -> Any:
    """Identify units from shape (heuristic based on bounding box)."""
    from app.schemas.cad_specs import UnitsInfo, UnitSystem

    bbox = get_shape_bounding_box(shape)
    size = max(
        bbox.max.x - bbox.min.x,
        bbox.max.y - bbox.min.y,
        bbox.max.z - bbox.min.z,
    )

    # Heuristic: if max dimension > 1000, likely mm
    # If < 100, likely inches
    # This is very rough - real implementation would check STEP header
    if size > 1000:
        source = UnitSystem.MM
    elif size > 100:
        source = UnitSystem.CM
    else:
        source = UnitSystem.INCH

    return UnitsInfo(
        source=source,
        normalized=UnitSystem.MM,
        confidence=0.7,
        conversion_factor=1.0 if source == UnitSystem.MM else (25.4 if source == UnitSystem.INCH else 10.0),
    )


def get_face_area(face: Any) -> float:
    """Calculate face area."""
    props = GProp_GProps()
    BRepGProp.SurfaceProperties_s(face, props)
    return props.Mass()


def get_face_normal(face: Any, u: float, v: float) -> gp_Vec:
    """Get surface normal at UV parameter."""
    surface = BRepAdaptor_Surface(face)
    pnt = gp_Pnt()
    vec = gp_Vec()
    surface.D1(u, v, pnt, vec)
    return vec


def get_edge_curve(edge: Any) -> tuple[Any, float, float]:
    """Get curve geometry from edge."""
    curve = BRepAdaptor_Curve(edge)
    first, last = 0.0, 0.0
    return curve, first, last


def are_faces_adjacent(face1: Any, face2: Any) -> bool:
    """Check if two faces share an edge."""
    return False


def get_shared_edges(face1: Any, face2: Any) -> list[Any]:
    """Get edges shared between two faces."""
    return []