"""Pytest configuration for the local JobEval backend.

Tests use a throwaway SQLite database and data directory under ``tmp_path`` so
no Redis, Celery, PostgreSQL, or Docker is required.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

import app.models  # noqa: F401  - register all tables on Base.metadata
from app.core.config import get_settings, reset_settings_cache
from app.core.database import db_manager
from app.main import create_app


@pytest.fixture
def temp_settings(tmp_path, monkeypatch):
    """Point the app at an isolated temp data dir + SQLite database."""
    data_dir = tmp_path / "data"
    db_url = f"sqlite:///{(data_dir / 'jobeval.sqlite3').as_posix()}"
    monkeypatch.setenv("JOBEVAL_DATA_DIR", str(data_dir))
    monkeypatch.setenv("JOBEVAL_DATABASE_URL", db_url)
    reset_settings_cache()
    db_manager.close()
    settings = get_settings()
    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
    db_manager.init()
    db_manager.create_tables()
    yield settings
    db_manager.close()


@pytest.fixture
def client(temp_settings):
    """A TestClient backed by the isolated test database."""
    app = create_app()
    return TestClient(app)


@pytest.fixture
def db_session(temp_settings):
    """A raw SQLAlchemy session for direct DB assertions."""
    db_manager.init()
    session = db_manager.session_factory()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def auth_headers():
    return {}
