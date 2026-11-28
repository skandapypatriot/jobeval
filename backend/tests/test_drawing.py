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


def test_drawing_dimension_has_source_evidence(client, tmp_path):
    """Every extracted dimension must carry source page, bbox, and evidence."""
    project_id = client.post("/api/v1/projects", json={"name": "DrawEv"}).json()["id"]
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
    for dim in analysis["dimensions"]:
        assert dim["id"], f"Dimension missing id: {dim}"
        assert dim["type"] in {
            "diameter", "radius", "depth", "thread", "chamfer",
            "fillet_radius", "angular", "linear",
        }, f"Unknown dimension type: {dim['type']}"
        assert dim["unit"] == "mm", f"Dimension unit not mm: {dim['unit']}"
        assert "evidence" in dim, f"Dimension missing evidence: {dim}"
        assert "page" in dim["evidence"], f"Evidence missing page: {dim['evidence']}"
        assert "bbox" in dim["evidence"], f"Evidence missing bbox: {dim['evidence']}"
        assert len(dim["evidence"]["bbox"]) == 4


def test_drawing_title_block_fields(client, tmp_path):
    """Title block should expose part number, revision, material, finish, title."""
    project_id = client.post("/api/v1/projects", json={"name": "DrawTB"}).json()["id"]
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
    # title_block lives on the page object; title string is in candidates.
    page_tb = analysis["pages"][0].get("title_block") or {}
    cand_title = analysis.get("candidates", {}).get("title")
    found = dict(page_tb)
    if cand_title:
        found["title"] = cand_title
    assert found, f"No title block fields detected in page: {analysis['pages'][0].get('title_block')} or candidates: {analysis.get('candidates', {})}"
    found_keys = set(found.keys())
    assert found_keys & {
        "part_number", "revision", "material", "finish", "title", "scale",
    }, f"No recognised title block keys in: {found_keys}"


def test_drawing_gdt_candidates(client, tmp_path):
    """GD&T candidates (flatness, etc.) should be extracted from drawing text."""
    project_id = client.post("/api/v1/projects", json={"name": "DrawGDT"}).json()["id"]
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
    gdt = analysis.get("gdt") or []
    # The generated PDF contains "FLATNESS 0.1" which should be detected.
    assert len(gdt) >= 1, f"Expected GD&T candidates, got: {gdt}"
    for item in gdt:
        assert item["type"], f"GD&T item missing type: {item}"
        assert "page" in item, f"GD&T item missing page: {item}"
        assert "bbox" in item["evidence"], f"GD&T item missing evidence bbox: {item}"


def test_drawing_ocr_unavailable_when_engine_missing(client, tmp_path):
    """When Tesseract is not installed, the result must say OCR is unavailable
    rather than pretending an image was recognised."""
    project_id = client.post("/api/v1/projects", json={"name": "DrawOCR"}).json()["id"]
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
    ocr = analysis.get("ocr") or {}
    assert "available" in ocr
    assert "reason" in ocr
    assert ocr["available"] is False
    assert ocr["used"] is False


def test_drawing_rejects_unsupported_format(client, tmp_path):
    """Uploading a non-drawing file to the drawing parse endpoint must fail."""
    project_id = client.post("/api/v1/projects", json={"name": "DrawBad"}).json()["id"]
    bad_path = tmp_path / "not_a_drawing.txt"
    bad_path.write_text("this is not a drawing")
    with bad_path.open("rb") as stream:
        upload = client.post(
            f"/api/v1/projects/{project_id}/files",
            files={"file": ("not_a_drawing.txt", stream, "text/plain")},
        )
    # Upload should reject non-drawing extensions/content.
    assert upload.status_code == 415, upload.text
