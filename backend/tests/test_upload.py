"""File upload validation tests."""

from tests.helpers import write_dxf_drawing, write_pdf_drawing, write_step_block_with_hole


def _create_project(client):
    return client.post("/api/v1/projects", json={"name": "UploadProject"}).json()["id"]


def test_upload_step_file(client, tmp_path):
    project_id = _create_project(client)
    step_path = tmp_path / "part.stp"
    write_step_block_with_hole(step_path)
    with step_path.open("rb") as stream:
        response = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("part.stp", stream, "application/step")},
        )
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["extension"] == ".stp"
    assert body["mime_type"] == "application/step"
    assert body["size_bytes"] > 0
    assert body["sha256"]
    assert body["role"] == "model_3d"
    assert body["download_url"] == f"/api/v1/files/{body['id']}/download"
    return body


def test_upload_pdf_and_dxf(client, tmp_path):
    project_id = _create_project(client)
    pdf_path = tmp_path / "drawing.pdf"
    write_pdf_drawing(pdf_path)
    with pdf_path.open("rb") as stream:
        pdf_response = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("drawing.pdf", stream, "application/pdf")},
        )
    assert pdf_response.status_code == 201, pdf_response.text
    assert pdf_response.json()["extension"] == ".pdf"
    assert pdf_response.json()["role"] == "drawing_2d"

    dxf_path = tmp_path / "drawing.dxf"
    write_dxf_drawing(dxf_path)
    with dxf_path.open("rb") as stream:
        dxf_response = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("drawing.dxf", stream, "image/vnd.dxf")},
        )
    assert dxf_response.status_code == 201, dxf_response.text
    assert dxf_response.json()["extension"] == ".dxf"
    assert dxf_response.json()["role"] == "drawing_2d"


def test_upload_rejects_unsupported_extension(client):
    project_id = _create_project(client)
    response = client.post(
        f"/api/v1/projects/{project_id}/files",
        files={"file": ("notes.txt", b"hello", "text/plain")},
    )
    assert response.status_code == 415, response.text


def test_upload_rejects_empty_file(client):
    project_id = _create_project(client)
    response = client.post(
        f"/api/v1/projects/{project_id}/files",
        files={"file": ("empty.stp", b"", "application/step")},
    )
    assert response.status_code == 400, response.text


def test_upload_rejects_mismatched_content(client):
    project_id = _create_project(client)
    response = client.post(
        f"/api/v1/projects/{project_id}/files",
        files={"file": ("fake.stp", b"this is not a step file", "application/step")},
    )
    assert response.status_code == 415, response.text


def test_download_uploaded_file(client, tmp_path):
    project_id = _create_project(client)
    step_path = tmp_path / "part.stp"
    write_step_block_with_hole(step_path)
    with step_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("part.stp", stream, "application/step")},
        ).json()
    file_id = upload["id"]
    download = client.get(f"/api/v1/files/{file_id}/download")
    assert download.status_code == 200
    assert download.content == step_path.read_bytes()


def test_stored_file_fields(client, tmp_path):
    project_id = _create_project(client)
    step_path = tmp_path / "part.stp"
    write_step_block_with_hole(step_path)
    with step_path.open("rb") as stream:
        body = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("part.stp", stream, "application/step")},
        ).json()
    for field in ("extension", "mime_type", "size_bytes", "sha256"):
        assert field in body, field
    assert body["extension"] == ".stp"
    assert body["mime_type"] == "application/step"
    assert body["size_bytes"] == step_path.stat().st_size
    assert len(body["sha256"]) == 64
    # StoredFile exposes path/relative_path; ProjectFile stores relative_path.
    assert body["download_url"] == f"/api/v1/files/{body['id']}/download"
