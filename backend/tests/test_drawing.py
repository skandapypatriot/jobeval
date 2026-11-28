"""Drawing text extraction tests (PDF and DXF)."""

from tests.helpers import write_dxf_drawing, write_pdf_drawing


def test_pdf_text_extraction(client, tmp_path):
    project_id = client.post("/api/v1/projects", json={"name": "PDFProj"}).json()["id"]
    pdf_path = tmp_path / "drawing.pdf"
    write_pdf_drawing(pdf_path)
    with pdf_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("drawing.pdf", stream, "application/pdf")},
        ).json()
    response = client.post(
        f"/api/v1/projects/{project_id}/drawings/parse",
        json={"file_id": upload["id"]},
    )
    assert response.status_code == 200, response.text
    analysis = response.json()["analysis"]
    assert analysis["format"] == "pdf"
    assert analysis["total_pages"] >= 1
    texts = [t["text"] for t in analysis["dimensions"][0:0]]  # placeholder
    all_text = " ".join(t["text"] for p in analysis["pages"] for t in p["texts"])
    assert "PART NO" in all_text or "ABC-123" in all_text, all_text
    assert "AL 6061" in all_text or "MATERIAL" in all_text, all_text
    assert analysis["candidates"]["material"] is not None


def test_dxf_text_extraction(client, tmp_path):
    project_id = client.post("/api/v1/projects", json={"name": "DXFProj"}).json()["id"]
    dxf_path = tmp_path / "drawing.dxf"
    write_dxf_drawing(dxf_path)
    with dxf_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("drawing.dxf", stream, "image/vnd.dxf")},
        ).json()
    response = client.post(
        f"/api/v1/projects/{project_id}/drawings/parse",
        json={"file_id": upload["id"]},
    )
    assert response.status_code == 200, response.text
    analysis = response.json()["analysis"]
    assert analysis["format"] == "dxf"
    all_text = " ".join(t["text"] for p in analysis["pages"] for t in p["texts"])
    assert "PART NO" in all_text or "DXF-9" in all_text, all_text
    assert analysis["candidates"]["material"] is not None


def test_drawing_pages_have_dimensions_and_bbox(client, tmp_path):
    project_id = client.post("/api/v1/projects", json={"name": "DrawBBox"}).json()["id"]
    pdf_path = tmp_path / "drawing.pdf"
    write_pdf_drawing(pdf_path)
    with pdf_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("drawing.pdf", stream, "application/pdf")},
        ).json()
    analysis = client.post(
        f"/api/v1/projects/{project_id}/drawings/parse",
        json={"file_id": upload["id"]},
    ).json()["analysis"]
    page = analysis["pages"][0]
    assert "width" in page and "height" in page
    for dim in analysis["dimensions"]:
        assert "bbox" in dim
        assert len(dim["bbox"]) == 4
        assert "evidence" in dim
