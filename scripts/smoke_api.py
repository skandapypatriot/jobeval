"""Exercise the local JobEval vertical slice with a real fixture.

This is a smoke check, not a substitute for the automated test suite. It prints
JSON summaries that can be captured in a milestone report.

Usage:
    python scripts/smoke_api.py --fixture fixtures/block.step
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import httpx


def post_json(client: httpx.Client, url: str, payload: dict[str, Any]) -> httpx.Response:
    return client.post(url, json=payload)


def wait_for_job(client: httpx.Client, api: str, job_id: str, timeout: float = 90.0) -> dict[str, Any]:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        response = client.get(f"{api}/jobs/{job_id}")
        response.raise_for_status()
        job = response.json()
        if job.get("status") in {"completed", "failed", "cancelled"}:
            return job
        time.sleep(0.25)
    raise TimeoutError(f"Job {job_id} did not finish within {timeout} seconds")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api", default="http://127.0.0.1:8000/api/v1")
    parser.add_argument("--fixture", type=Path, default=Path("fixtures/block.step"))
    parser.add_argument("--project-name", default="API smoke project")
    args = parser.parse_args()

    if not args.fixture.is_file():
        parser.error(f"Fixture does not exist: {args.fixture}")

    api = args.api.rstrip("/")
    with httpx.Client(timeout=30.0) as client:
        health = client.get(f"{api}/health")
        health.raise_for_status()

        project_response = post_json(
            client,
            f"{api}/projects",
            {"name": args.project_name, "description": "Created by scripts/smoke_api.py"},
        )
        project_response.raise_for_status()
        project = project_response.json()
        project_id = project["id"]

        with args.fixture.open("rb") as handle:
            upload_response = client.post(
                f"{api}/projects/{project_id}/files",
                files={"file": (args.fixture.name, handle, "application/octet-stream")},
            )
        upload_response.raise_for_status()
        source_file = upload_response.json()

        analysis_response = post_json(
            client,
            f"{api}/projects/{project_id}/analysis",
            {"file_id": source_file["id"]},
        )
        analysis_response.raise_for_status()
        analysis = analysis_response.json()
        job_id = analysis.get("job_id") or analysis.get("id")
        job = wait_for_job(client, api, job_id)

        result: dict[str, Any] = {
            "health": health.json(),
            "project_id": project_id,
            "file_id": source_file["id"],
            "job": {
                "id": job_id,
                "status": job.get("status"),
                "progress": job.get("progress"),
                "error": job.get("error"),
            },
        }

        if job.get("status") == "completed":
            analysis_result = client.get(f"{api}/projects/{project_id}/analysis")
            analysis_result.raise_for_status()
            payload = analysis_result.json()
            geometry = payload.get("geometry", payload)
            result["geometry"] = {
                "units": geometry.get("units"),
                "body_count": geometry.get("body_count"),
                "dimensions_mm": geometry.get("dimensions_mm"),
                "volume_mm3": geometry.get("volume_mm3"),
                "surface_area_mm2": geometry.get("surface_area_mm2"),
            }
            features = client.get(f"{api}/projects/{project_id}/features")
            features.raise_for_status()
            feature_payload = features.json()
            items = feature_payload.get("features", feature_payload if isinstance(feature_payload, list) else [])
            result["features"] = [
                {
                    "id": item.get("id"),
                    "type": item.get("type"),
                    "confidence": item.get("confidence"),
                    "review_status": item.get("review_status"),
                }
                for item in items
            ]

        print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
