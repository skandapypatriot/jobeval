"""Consistent project report generation for JSON, HTML, and CSV."""

from __future__ import annotations

import csv
import html
import io
import json
from typing import Any


def build_report(
    project: Any,
    analysis: dict[str, Any] | None,
    plan: dict[str, Any] | None,
    estimate: dict[str, Any] | None,
    drawings: dict[str, Any] | None = None,
    cross_validation: dict[str, Any] | None = None,
) -> dict[str, Any]:
    geometry = (analysis or {}).get("geometry") or (analysis or {}).get("geometry_summary") or {}
    features = (analysis or {}).get("features") or []
    return {
        "report_version": "1.0",
        "project": {
            "id": getattr(project, "id", None),
            "name": getattr(project, "name", None),
            "description": getattr(project, "description", None),
            "status": getattr(project, "status", None),
        },
        "geometry": geometry,
        "features": features,
        "feature_count": len(features),
        "manufacturing_plan": plan or {},
        "estimate": estimate or {},
        "drawings": drawings or {},
        "cross_validation": cross_validation or {},
        "totals": {
            "estimated_cost": (estimate or {}).get("total"),
            "currency": (estimate or {}).get("currency"),
            "operation_count": len((plan or {}).get("operations", [])),
        },
    }


def report_json(report: dict[str, Any]) -> str:
    return json.dumps(report, indent=2, sort_keys=True, default=str)


def report_html(report: dict[str, Any]) -> str:
    project = report.get("project", {})
    geometry = report.get("geometry", {})
    bbox = geometry.get("bbox", {})
    low, high = bbox.get("min", {}), bbox.get("max", {})
    estimate = report.get("estimate", {})
    rows = []
    for line in estimate.get("lines", []):
        rows.append(
            "<tr>"
            f"<td>{html.escape(str(line.get('label', '')))}</td>"
            f"<td>{html.escape(str(line.get('formula', '')))}</td>"
            f"<td>{html.escape(str(line.get('subtotal', 'unpriced')))}</td>"
            "</tr>"
        )
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>JobEval report - {html.escape(str(project.get("name", "Project")))}</title>
<style>body{{font-family:system-ui,sans-serif;margin:2rem;color:#222}}table{{border-collapse:collapse;width:100%}}td,th{{border:1px solid #ccc;padding:.4rem;text-align:left}}th{{background:#f2f2f2}}.warning{{color:#a00}}</style></head>
<body><h1>JobEval report</h1><p><strong>Project:</strong> {html.escape(str(project.get("name", "")))} ({html.escape(str(project.get("id", "")))} )</p>
<h2>Geometry</h2><p>Volume: {geometry.get("volume", "n/a")} mm³; area: {geometry.get("surface_area", "n/a")} mm²</p>
<p>BBox: ({low.get("x", "n/a")}, {low.get("y", "n/a")}, {low.get("z", "n/a")}) to ({high.get("x", "n/a")}, {high.get("y", "n/a")}, {high.get("z", "n/a")})</p>
<h2>Estimate</h2><p>Total: {estimate.get("total", "unpriced")} {estimate.get("currency", "")}</p>
<table><thead><tr><th>Line</th><th>Formula</th><th>Subtotal</th></tr></thead><tbody>{"".join(rows)}</tbody></table>
<h2>Cross-validation</h2><p>{html.escape(str((report.get("cross_validation") or {}).get("status", "not run")))}</p>
</body></html>"""


def report_csv(report: dict[str, Any]) -> str:
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["section", "key", "value"])
    writer.writerow(["project", "id", report.get("project", {}).get("id", "")])
    writer.writerow(["project", "name", report.get("project", {}).get("name", "")])
    geometry = report.get("geometry", {})
    writer.writerow(["geometry", "volume_mm3", geometry.get("volume", "")])
    writer.writerow(["geometry", "surface_area_mm2", geometry.get("surface_area", "")])
    for line in report.get("estimate", {}).get("lines", []):
        writer.writerow(
            ["estimate", line.get("label", line.get("id", "")), line.get("subtotal", "unpriced")]
        )
    for feature in report.get("features", []):
        writer.writerow(["feature", feature.get("feature_id", ""), feature.get("type", "")])
    return output.getvalue()
