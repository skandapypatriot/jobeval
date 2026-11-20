@echo off
REM Ingest raw test files - drag and drop a folder onto this batch file
REM or run: ingest_testdata.bat "C:\path\to\your\cad_files"

cd /d "%~dp0\.."
python scripts\ingest_testdata.py %*
pause