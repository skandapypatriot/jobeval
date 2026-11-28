"""STEP/B-Rep import and geometry extraction.

build123d 0.13 is the supported modelling/export layer and OCP (the OCCT
binding used by build123d) is used for the import, topology, and tessellation
operations.  pythonocc-core is intentionally *not* required and is not
silently emulated: this service reports an actionable error if OCP is absent.
"""

from __future__ import annotations

import hashlib
import re
import time
from pathlib import Path
from typing import Any

from app.services.feature_recognition import recognize_features

try:
    from OCP.Bnd import Bnd_Box
    from OCP.BRep import BRep_Tool
    from OCP.BRepAdaptor import BRepAdaptor_Surface
    from OCP.BRepBndLib import BRepBndLib
    from OCP.BRepCheck import BRepCheck_Analyzer
    from OCP.BRepGProp import BRepGProp
    from OCP.GProp import GProp_GProps
    from OCP.IFSelect import IFSelect_ReturnStatus
    from OCP.Poly import Poly_Triangulation
    from OCP.STEPControl import STEPControl_Reader
    from OCP.TopAbs import TopAbs_EDGE, TopAbs_FACE, TopAbs_SHELL, TopAbs_SOLID, TopAbs_VERTEX
    from OCP.TopExp import TopExp_Explorer
    from OCP.TopLoc import TopLoc_Location
    from OCP.TopoDS import TopoDS, TopoDS_Shape
except Exception as exc:  # pragma: no cover
    _OCP_IMPORT_ERROR = exc
    BRep_Tool = BRepAdaptor_Surface = BRepBndLib = BRepCheck_Analyzer = BRepGProp = Bnd_Box = (
        GProp_GProps
    ) = None
    IFSelect_ReturnStatus = Poly_Triangulation = STEPControl_Reader = None
    TopAbs_EDGE = TopAbs_FACE = TopAbs_SHELL = TopAbs_SOLID = TopAbs_VERTEX = None
    TopExp_Explorer = TopLoc_Location = TopoDS = TopoDS_Shape = None
else:
    _OCP_IMPORT_ERROR = None


_STEP_UNIT_PATTERNS = (
    (re.compile(r"SI_UNIT\s*\(\s*\.MILLI\.\s*,\s*\.METRE\.\s*\)", re.I), "mm", 1.0),
    (re.compile(r"SI_UNIT\s*\(\s*\.CENTI\.\s*,\s*\.METRE\.\s*\)", re.I), "cm", 10.0),
    (re.compile(r"SI_UNIT\s*\(\s*\.METRE\.\s*,\s*\.METRE\.\s*\)", re.I), "m", 1000.0),
    (re.compile(r"CONVERSION_BASED_UNIT\s*\(\s*['\"]INCH['\"]", re.I), "inch", 25.4),
    (re.compile(r"CONVERSION_BASED_UNIT\s*\(\s*['\"]FOOT['\"]", re.I), "foot", 304.8),
)


def _round(value: float, digits: int = 5) -> float:
    return round(float(value), digits)


def _vec(x: float, y: float, z: float) -> dict[str, float]:
    return {"x": _round(x), "y": _round(y), "z": _round(z)}


def _bbox(shape: Any) -> tuple[dict[str, float], dict[str, float]]:
    box = Bnd_Box()
    BRepBndLib.Add_s(shape, box)
    low = box.CornerMin()
    high = box.CornerMax()
    return _vec(low.X(), low.Y(), low.Z()), _vec(high.X(), high.Y(), high.Z())


def _topology_count(shape: Any, kind: Any) -> int:
    count = 0
    explorer = TopExp_Explorer(shape, kind)
    while explorer.More():
        count += 1
        explorer.Next()
    return count


def _mass_properties(shape: Any) -> tuple[float, float, dict[str, float]]:
    volume_props = GProp_GProps()
    BRepGProp.VolumeProperties_s(shape, volume_props)
    centre = volume_props.CentreOfMass()
    return (
        float(volume_props.Mass()),
        float(volume_props.Mass()),
        _vec(centre.X(), centre.Y(), centre.Z()),
    )


def _surface_area(shape: Any) -> float:
    props = GProp_GProps()
    BRepGProp.SurfaceProperties_s(shape, props)
    return float(props.Mass())


def _file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def detect_source_units(path: Path) -> dict[str, Any]:
    """Inspect STEP declarations and report source/normalized units."""

    text = path.read_text(encoding="utf-8", errors="ignore")
    found: list[tuple[str, float]] = []
    for pattern, unit, factor in _STEP_UNIT_PATTERNS:
        if pattern.search(text):
            found.append((unit, factor))
    # Keep declaration order but remove duplicates.
    unique: list[tuple[str, float]] = []
    for item in found:
        if item not in unique:
            unique.append(item)
    if not unique:
        return {
            "source": "unknown",
            "normalized": "mm",
            "conversion_factor": 1.0,
            "confidence": 0.25,
            "ambiguous": True,
            "declarations": [],
            "warning": "No explicit length unit declaration was found; assuming millimetres.",
        }
    names = {name for name, _ in unique}
    ambiguous = len(names) > 1
    source, factor = unique[0]
    return {
        "source": source,
        "normalized": "mm",
        "conversion_factor": factor,
        "confidence": 0.45 if ambiguous else 0.98,
        "ambiguous": ambiguous,
        "declarations": [{"unit": name, "conversion_factor": value} for name, value in unique],
        "warning": (
            "Multiple length-unit declarations were found; the first declaration was used and the result needs review."
            if ambiguous
            else None
        ),
    }


def _face_type(face: Any) -> str:
    try:
        surface = BRepAdaptor_Surface(face)
        value = str(surface.GetType()).lower()
        for name in ("plane", "cylinder", "cone", "torus", "sphere", "bspline"):
            if name in value:
                return name
        return "other"
    except Exception:
        return "unknown"


def _face_area(face: Any) -> float:
    props = GProp_GProps()
    BRepGProp.SurfaceProperties_s(face, props)
    return float(props.Mass())


def _face_centre(face: Any) -> tuple[float, float, float]:
    props = GProp_GProps()
    BRepGProp.SurfaceProperties_s(face, props)
    point = props.CentreOfMass()
    return point.X(), point.Y(), point.Z()


def _tessellate_face(face: Any, deflection: float) -> dict[str, Any]:
    """Return a compact per-face triangle mesh suitable for a CustomPainter."""

    location = TopLoc_Location()
    triangulation = BRep_Tool.Triangulation_s(face, location)
    if triangulation is None:
        return {"vertices": [], "triangles": [], "vertex_count": 0, "triangle_count": 0}
    transform = location.Transformation()
    vertices: list[dict[str, float]] = []
    for index in range(1, triangulation.NbNodes() + 1):
        point = triangulation.Node(index).Transformed(transform)
        vertices.append(_vec(point.X(), point.Y(), point.Z()))
    triangles: list[list[int]] = []
    for index in range(1, triangulation.NbTriangles() + 1):
        triangle = triangulation.Triangle(index).Get()
        # OCCT triangle indices are one-based.
        triangles.append([int(triangle[0]) - 1, int(triangle[1]) - 1, int(triangle[2]) - 1])
    return {
        "vertices": vertices,
        "triangles": triangles,
        "vertex_count": len(vertices),
        "triangle_count": len(triangles),
    }


class CADService:
    """Import and inspect STEP geometry without modifying the source file."""

    def __init__(
        self, mesh_deflection: float | None = None, mesh_angle: float | None = None
    ) -> None:
        from app.core.config import get_settings

        settings = get_settings()
        self.mesh_deflection = (
            mesh_deflection if mesh_deflection is not None else settings.MESH_DEFLECTION
        )
        self.mesh_angle = mesh_angle if mesh_angle is not None else settings.MESH_ANGLE

    def import_step(self, file_path: Path) -> Any:
        if _OCP_IMPORT_ERROR is not None:
            raise RuntimeError(
                "STEP import requires OCP, the OCCT binding used by build123d 0.13. "
                f"OCP could not be imported: {_OCP_IMPORT_ERROR}"
            )
        reader = STEPControl_Reader()
        status = reader.ReadFile(str(file_path))
        if status != IFSelect_ReturnStatus.IFSelect_RetDone:
            raise ValueError(f"Failed to read STEP file (status: {status})")
        reader.TransferRoots()
        shape = reader.OneShape()
        if shape is None or shape.IsNull():
            raise ValueError("STEP file contains no geometry")
        return shape

    def validate_geometry(self, shape: Any) -> list[str]:
        analyzer = BRepCheck_Analyzer(shape)
        if not analyzer.IsValid():
            return ["Geometry validation failed: invalid topology"]
        return []

    def extract_geometry_summary(self, shape: Any) -> dict[str, Any]:
        low, high = _bbox(shape)
        volume_props = GProp_GProps()
        BRepGProp.VolumeProperties_s(shape, volume_props)
        centre = volume_props.CentreOfMass()
        return {
            "num_bodies": _topology_count(shape, TopAbs_SOLID),
            "num_shells": _topology_count(shape, TopAbs_SHELL),
            "num_faces": _topology_count(shape, TopAbs_FACE),
            "num_edges": _topology_count(shape, TopAbs_EDGE),
            "num_vertices": _topology_count(shape, TopAbs_VERTEX),
            "volume": _round(volume_props.Mass()),
            "surface_area": _round(_surface_area(shape)),
            "bbox": {"min": low, "max": high},
            "center_of_mass": _vec(centre.X(), centre.Y(), centre.Z()),
            "principal_axes": [_vec(1, 0, 0), _vec(0, 1, 0), _vec(0, 0, 1)],
            "symmetry": {},
        }

    def extract_solid_bodies(self, shape: Any) -> list[dict[str, Any]]:
        bodies: list[dict[str, Any]] = []
        explorer = TopExp_Explorer(shape, TopAbs_SOLID)
        while explorer.More():
            solid = explorer.Current()
            low, high = _bbox(solid)
            props = GProp_GProps()
            BRepGProp.VolumeProperties_s(solid, props)
            centre = props.CentreOfMass()
            analyzer = BRepCheck_Analyzer(solid)
            body = {
                "body_id": f"body_{len(bodies):03d}",
                "volume": _round(props.Mass()),
                "surface_area": _round(_surface_area(solid)),
                "bbox": {"min": low, "max": high},
                "center_of_mass": _vec(centre.X(), centre.Y(), centre.Z()),
                "num_faces": _topology_count(solid, TopAbs_FACE),
                "num_edges": _topology_count(solid, TopAbs_EDGE),
                "num_vertices": _topology_count(solid, TopAbs_VERTEX),
                "is_valid": bool(analyzer.IsValid()),
                "validation_errors": [] if analyzer.IsValid() else ["Invalid topology"],
            }
            bodies.append(body)
            explorer.Next()
        return bodies

    def tessellate(self, shape: Any) -> list[dict[str, Any]]:
        """Generate per-face tessellations and surface metadata."""

        # BRepMesh_IncrementalMesh is in a separate OCP module and is kept out
        # of the import guard above to make the unsupported-kernel error clear.
        try:
            from OCP.BRepMesh import BRepMesh_IncrementalMesh
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(f"OCP tessellation support is unavailable: {exc}") from exc
        BRepMesh_IncrementalMesh(shape, self.mesh_deflection, False, self.mesh_angle, True)
        result: list[dict[str, Any]] = []
        explorer = TopExp_Explorer(shape, TopAbs_FACE)
        while explorer.More():
            face = TopoDS.Face(explorer.Current())
            low, high = _bbox(face)
            centre = _face_centre(face)
            result.append(
                {
                    "face_id": f"face_{len(result):04d}",
                    "surface_type": _face_type(face),
                    "area": _round(_face_area(face)),
                    "bbox": {"min": low, "max": high},
                    "center": _vec(*centre),
                    "mesh": _tessellate_face(face, self.mesh_deflection),
                }
            )
            explorer.Next()
        return result

    def process_step(self, file_path: Path, file_id: str | None = None) -> dict[str, Any]:
        """Process a STEP file and return a JSON-serialisable analysis."""

        started = time.time()
        path = Path(file_path)
        units = detect_source_units(path)
        shape = self.import_step(path)
        warnings: list[dict[str, Any]] = []
        validation_errors = self.validate_geometry(shape)
        if units.get("warning"):
            warnings.append(
                {"code": "unit_ambiguity", "message": units["warning"], "severity": "warning"}
            )
        for message in validation_errors:
            warnings.append({"code": "invalid_geometry", "message": message, "severity": "warning"})
        geometry = self.extract_geometry_summary(shape)
        bodies = self.extract_solid_bodies(shape)
        faces = self.tessellate(shape)
        try:
            recognition = recognize_features(shape, units)
            features = (
                recognition.get("raw_features", [])
                if isinstance(recognition, dict)
                else recognition
            )
        except Exception as exc:
            features = []
            warnings.append(
                {"code": "feature_recognition_failed", "message": str(exc), "severity": "warning"}
            )
        return {
            "source_file": {
                "id": file_id,
                "filename": path.name,
                "sha256": _file_hash(path),
                "size_bytes": path.stat().st_size,
            },
            "units": units,
            "geometry": geometry,
            "geometry_summary": geometry,
            "solid_bodies": bodies,
            "faces": faces,
            "mesh": {"faces": faces, "format": "per_face_triangles"},
            "features": features,
            "raw_features": features,
            "reviewed_features": {},
            "warnings": warnings,
            "valid": not bool(validation_errors),
            "processing_time_seconds": _round(time.time() - started, 4),
            "kernel": "build123d-0.13/OCP",
        }

    # Compatibility with the original scaffold's method name.
    def process_cad_file(self, file_path: Path, project_id: Any) -> dict[str, Any]:
        return self.process_step(Path(file_path), str(project_id))
