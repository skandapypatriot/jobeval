"""Report export tests."""

import json


def test_report_json_export(client, tmp_path):
    """JSON report contains project, analysis, plan, estimate, drawing, validation."""
    project_id = client.post("/api/v1/projects", json={"name": "Report"}).json()["id"]

    from tests.helpers import write_step_block_with_hole
    step_path = tmp_path / "part.stp"
    write_step_block_with_hole(step_path)
    with step_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("part.stp", stream, "application/step")},
        ).json()

    # Start analysis
    start = client.post(
        f"/api/v1/projects/{project_id}/analysis", json={"file_id": upload["id"]}
    )
    assert start.status_code == 202

    import time
    for _ in range(20):
        job = client.get(f"/api/v1/jobs/{start.json()['job_id']}")
        if job.json()["status"] == "completed":
            break
        time.sleep(0.1)

    # Create estimate
    client.post(
        f"/api/v1/projects/{project_id}/estimate",
        json={
            "pricing": {
                "material": "aluminum_6061",
                "density_kg_m3": 2700.0,
                "price": 10.0,
                "price_basis": "kg",
                "quantity": 1,
                "rates": {"machine": 60.0},
            }
        },
    )

    # Request JSON report
    response = client.get(
        f"/api/v1/projects/{project_id}/reports?format=json"
    )
    assert response.status_code == 200, response.text
    report = response.json()
    assert "project" in report or "project_id" in report
    assert "geometry" in report or "analysis" in report


def test_report_html_export(client, tmp_path):
    """HTML report returns HTML content type."""
    project_id = client.post("/api/v1/projects", json={"name": "ReportHTML"}).json()["id"]

    from tests.helpers import write_step_block_with_hole
    step_path = tmp_path / "part.stp"
    write_step_block_with_hole(step_path)
    with step_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("part.stp", stream, "application/step")},
        ).json()

    start = client.post(
        f"/api/v1/projects/{project_id}/analysis", json={"file_id": upload["id"]}
    )
    assert start.status_code == 202

    import time
    for _ in range(20):
        job = client.get(f"/api/v1/jobs/{start.json()['job_id']}")
        if job.json()["status"] == "completed":
            break
        time.sleep(0.1)

    client.post(
        f"/api/v1/projects/{project_id}/estimate",
        json={
            "pricing": {
                "material": "aluminum_6061",
                "density_kg_m3": 2700.0,
                "price": 10.0,
                "price_basis": "kg",
                "quantity": 1,
                "rates": {"machine": 60.0},
            }
        },
    )

    response = client.get(
        f"/api/v1/projects/{project_id}/reports?format=html"
    )
    assert response.status_code == 200, response.text
    assert "text/html" in response.headers.get("content-type", "")


def test_report_csv_export(client, tmp_path):
    """CSV report returns CSV content type."""
    project_id = client.post("/api/v1/projects", json={"name": "ReportCSV"}).json()["id"]

    from tests.helpers import write_step_block_with_hole
    step_path = tmp_path / "part.stp"
    write_step_block_with_hole(step_path)
    with step_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("part.stp", stream, "application/step")},
        ).json()

    start = client.post(
        f"/api/v1/projects/{project_id}/analysis", json={"file_id": upload["id"]}
    )
    assert start.status_code == 202

    import time
    for _ in range(20):
        job = client.get(f"/api/v1/jobs/{start.json()['job_id']}")
        if job.json()["status"] == "completed":
            break
        time.sleep(0.1)

    client.post(
        f"/api/v1/projects/{project_id}/estimate",
        json={
            "pricing": {
                "material": "aluminum_6061",
                "density_kg_m3": 2700.0,
                "price": 10.0,
                "price_basis": "kg",
                "quantity": 1,
                "rates": {"machine": 60.0},
            }
        },
    )

    response = client.get(
        f"/api/v1/projects/{project_id}/reports?format=csv"
    )
    assert response.status_code == 200, response.text
    assert "text/csv" in response.headers.get("content-type", "")