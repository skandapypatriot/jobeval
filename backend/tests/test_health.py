"""Health endpoint tests."""


def test_health_checks_database_and_storage(client):
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["service"] == "jobeval-backend"
    assert body["status"] in {"healthy", "degraded"}
    assert body["database"] == "ok", body
    assert body["storage"] == "ok", body

    api_response = client.get("/api/v1/health")
    assert api_response.status_code == 200
    assert api_response.json() == body
