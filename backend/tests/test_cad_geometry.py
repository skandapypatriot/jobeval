"""CAD geometry import / analysis tests."""

from tests.helpers import write_step_block_with_hole


def test_process_step_known_volume_and_dimensions(client, tmp_path):
    project_id = client.post("/api/v1/projects", json={"name": "Geo"}).json()["id"]
    step_path = tmp_path / "part.stp"
    write_step_block_with_hole(step_path)
    with step_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("part.stp", stream, "application/step")},
        ).json()
    file_id = upload["id"]

    from app.services.cad_service import CADService

    result = CADService().process_step(step_path, file_id)
    assert result["valid"] is True
    geometry = result["geometry_summary"]
    # Box 40 x 30 x 20 minus a 12 dia x 20 deep hole:
    # 24000 - pi*36*20 = 24000 - 2261.95 = 21738.05
    assert abs(geometry["volume"] - 21738.05) < 5, geometry["volume"]
    bbox = geometry["bbox"]
    assert abs(bbox["max"]["x"] - bbox["min"]["x"] - 40) < 1e-3, bbox
    assert abs(bbox["max"]["y"] - bbox["min"]["y"] - 30) < 1e-3, bbox
    assert abs(bbox["max"]["z"] - bbox["min"]["z"] - 20) < 1e-3, bbox
    assert geometry["num_bodies"] == 1
    assert result["units"]["conversion_factor"] == 1.0


def test_process_step_via_analysis_job(client, tmp_path):
    project_id = client.post("/api/v1/projects", json={"name": "JobGeo"}).json()["id"]
    step_path = tmp_path / "part.stp"
    write_step_block_with_hole(step_path)
    with step_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("part.stp", stream, "application/step")},
        ).json()
    start = client.post(f"/api/v1/projects/{project_id}/analysis", json={"file_id": upload["id"]})
    assert start.status_code == 202, start.text
    job_id = start.json()["job_id"]
    job = client.get(f"/api/v1/jobs/{job_id}")
    assert job.status_code == 200
    assert job.json()["status"] in {"queued", "running", "completed", "failed"}
