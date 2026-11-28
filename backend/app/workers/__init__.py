"""Local JobEval workers.

The local worker is intentionally broker-free.  Legacy Celery task modules are
kept out of the import path so importing the API never requires Redis.
"""

from app.workers.local_analysis import run_analysis_job, run_job_in_background

__all__ = ["run_analysis_job", "run_job_in_background"]
