"""Project CRUD tests."""


def test_create_and_list_project(client):
    response = client.post(
        "/api/v1/projects", json={"name": "Bracket", "description": "A test bracket"}
    )
    assert response.status_code == 201, response.text
    project = response.json()
    assert project["name"] == "Bracket"
    assert project["id"]
    assert isinstance(project["id"], str)
    assert project["file_count"] == 0

    list_response = client.get("/api/v1/projects")
    assert list_response.status_code == 200
    body = list_response.json()
    assert body["total"] >= 1
    assert any(p["id"] == project["id"] for p in body["items"])


def test_get_project(client):
    create = client.post("/api/v1/projects", json={"name": "Gear"})
    project_id = create.json()["id"]
    response = client.get(f"/api/v1/projects/{project_id}")
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == project_id
    assert body["name"] == "Gear"


def test_patch_project(client):
    create = client.post("/api/v1/projects", json={"name": "Old"})
    project_id = create.json()["id"]
    response = client.patch(
        f"/api/v1/projects/{project_id}", json={"name": "New", "status": "completed"}
    )
    assert response.status_code == 200
    assert response.json()["name"] == "New"
    assert response.json()["status"] == "completed"


def test_delete_project(client):
    create = client.post("/api/v1/projects", json={"name": "ToDelete"})
    project_id = create.json()["id"]
    response = client.delete(f"/api/v1/projects/{project_id}")
    assert response.status_code == 204
    gone = client.get(f"/api/v1/projects/{project_id}")
    assert gone.status_code == 404


def test_demo_project(client):
    response = client.post("/api/v1/projects/demo")
    assert response.status_code == 201
    assert response.json()["is_demo"] is True


def test_project_id_is_string(client):
    response = client.post("/api/v1/projects", json={"name": "StrID"})
    assert response.status_code == 201
    assert isinstance(response.json()["id"], str)
