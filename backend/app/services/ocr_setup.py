"""OCR auto-setup: downloads and configures Tesseract OCR for Windows.

This module attempts to download and install Tesseract OCR automatically so
that scanned PDF drawings can be processed without manual installation.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


TESSERACT_VERSION = "5.3.3.20221222"
TESSERACT_URL = (
    "https://github.com/UB-Mannheim/tesseract/wiki"
    f"/releases/download/{TESSERACT_VERSION}/tesseract-ocr-w64-setup-{TESSERACT_VERSION}.exe"
)
TESSERACT_INSTALL_DIR = Path(r"C:\Program Files\Tesseract-OCR")
TESSERACT_EXE = TESSERACT_INSTALL_DIR / "tesseract.exe"


def is_tesseract_available() -> bool:
    """Check if Tesseract OCR is available on the system."""
    return shutil.which("tesseract") is not None or TESSERACT_EXE.exists()


def get_tesseract_path() -> str | None:
    """Get the path to the Tesseract executable."""
    if shutil.which("tesseract"):
        return shutil.which("tesseract")
    if TESSERACT_EXE.exists():
        return str(TESSERACT_EXE)
    return None


def try_auto_install() -> dict[str, Any]:
    """Attempt to automatically download and install Tesseract OCR.

    Returns a dict with installation status and instructions.
    """
    if is_tesseract_available():
        return {
            "installed": True,
            "method": "already_available",
            "path": get_tesseract_path(),
            "message": "Tesseract OCR is already available.",
        }

    # Check if we're on Windows
    if os.name != "nt":
        return {
            "installed": False,
            "method": "unsupported_platform",
            "message": "Automatic Tesseract installation is only supported on Windows.",
            "instructions": [
                "Install Tesseract OCR manually from: https://github.com/UB-Mannheim/tesseract/wiki",
                "Add Tesseract to your Windows PATH environment variable.",
                "Restart JobEval backend after installation.",
            ],
        }

    # Try to download and install
    temp_dir = Path(tempfile.mkdtemp())
    installer_path = temp_dir / "tesseract-setup.exe"

    try:
        import urllib.request

        print(f"Downloading Tesseract OCR from {TESSERACT_URL}...")
        urllib.request.urlretrieve(TESSERACT_URL, installer_path)

        print("Running Tesseract installer...")
        result = subprocess.run(
            [str(installer_path), "/SILENT", "/SUPPRESSMSGBOXES", "/CLOSEAPPLICATIONS"],
            capture_output=True,
            text=True,
            timeout=300,
        )

        if result.returncode == 0 and is_tesseract_available():
            return {
                "installed": True,
                "method": "auto_installed",
                "path": get_tesseract_path(),
                "message": "Tesseract OCR installed automatically.",
            }

        return {
            "installed": False,
            "method": "auto_install_failed",
            "message": f"Auto-installation failed (exit code {result.returncode}).",
            "stderr": result.stderr,
            "instructions": [
                "Install Tesseract OCR manually from: https://github.com/UB-Mannheim/tesseract/wiki",
                "Add Tesseract to your Windows PATH environment variable.",
                "Restart JobEval backend after installation.",
            ],
        }

    except Exception as exc:  # pylint: disable=broad-except
        return {
            "installed": False,
            "method": "auto_install_error",
            "message": f"Auto-installation error: {exc}",
            "instructions": [
                "Install Tesseract OCR manually from: https://github.com/UB-Mannheim/tesseract/wiki",
                "Add Tesseract to your Windows PATH environment variable.",
                "Restart JobEval backend after installation.",
            ],
        }
    finally:
        # Clean up temp files
        try:
            if installer_path.exists():
                installer_path.unlink()
            temp_dir.rmdir()
        except Exception:
            pass


def get_ocr_status() -> dict[str, Any]:
    """Get comprehensive OCR status for the drawing service."""
    available = is_tesseract_available()
    path = get_tesseract_path() if available else None

    if available:
        # Try to get version
        version = "unknown"
        try:
            result = subprocess.run(
                [path, "--version"], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                version = result.stdout.strip().split("\n")[0]
        except Exception:
            pass

        return {
            "available": True,
            "reason": "Tesseract OCR is available",
            "path": path,
            "version": version,
            "used": False,
        }

    return {
        "available": False,
        "reason": "Tesseract executable is not installed",
        "path": None,
        "version": None,
        "used": False,
        "install_instructions": [
            "Download Tesseract OCR from: https://github.com/UB-Mannheim/tesseract/wiki",
            "Run the installer and add Tesseract to your Windows PATH.",
            "Restart JobEval backend after installation.",
            "Or run: python -c \"from app.services.ocr_setup import try_auto_install; try_auto_install()\"",
        ],
    }
