"""SQLAlchemy 2 database setup.

JobEval uses a small SQLite database by default.  The session dependency is
synchronous on purpose: it keeps the local API usable from scripts, tests, and
ordinary ``uvicorn`` processes without an async driver or a broker.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings


class Base(DeclarativeBase):
    """Base class for all JobEval tables."""


class DatabaseManager:
    """Owns the SQLAlchemy engine and session factory."""

    def __init__(self) -> None:
        self._engine: Engine | None = None
        self._session_factory: sessionmaker[Session] | None = None

    def init(self) -> None:
        if self._engine is not None and self._session_factory is not None:
            return
        settings = get_settings()
        url = settings.database_url
        if not url.startswith("sqlite"):
            raise RuntimeError(
                "The local JobEval backend currently supports SQLite only. "
                "Set DATABASE_URL to a sqlite:/// URL."
            )
        self._engine = create_engine(
            url,
            connect_args={"check_same_thread": False},
            pool_pre_ping=True,
            future=True,
        )

        @event.listens_for(self._engine, "connect")
        def _enable_sqlite_foreign_keys(dbapi_connection, _connection_record):
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

        self._session_factory = sessionmaker(
            bind=self._engine,
            class_=Session,
            autoflush=False,
            expire_on_commit=False,
        )

    def close(self) -> None:
        if self._engine is not None:
            self._engine.dispose()
        self._engine = None
        self._session_factory = None

    @property
    def engine(self) -> Engine:
        if self._engine is None:
            self.init()
        assert self._engine is not None
        return self._engine

    @property
    def session_factory(self) -> sessionmaker[Session]:
        if self._session_factory is None:
            self.init()
        assert self._session_factory is not None
        return self._session_factory

    @contextmanager
    def session(self) -> Iterator[Session]:
        session = self.session_factory()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    def create_tables(self) -> None:
        # Importing models registers all tables on Base.metadata.
        from app import models  # noqa: F401

        Base.metadata.create_all(self.engine)

    def drop_tables(self) -> None:
        from app import models  # noqa: F401

        Base.metadata.drop_all(self.engine)


db_manager = DatabaseManager()


def get_db_session() -> Iterator[Session]:
    """FastAPI dependency yielding a request-scoped SQLAlchemy session."""

    db_manager.init()
    session = db_manager.session_factory()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


# A compatibility alias used by a few early scripts.
get_db = get_db_session
