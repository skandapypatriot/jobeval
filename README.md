# JobEval — Intelligent CAD Analysis & CNC Cost Estimation

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()
[![Python](https://img.shields.io/badge/python-3.11%2B-blue)]()
[![Flutter](https://img.shields.io/badge/flutter-3.22%2B-blue)]()
[![NVIDIA NIM](https://img.shields.io/badge/LLM-Nemotron%203.5-blue)]()

JobEval is a cross-platform application for analyzing CAD models and engineering drawings, recognizing manufacturing features, and generating CNC machining cost estimates. Built with a **Flutter frontend** and **Python/FastAPI backend** powered by OpenCASCADE.

## 🎯 Project Status

All phases complete and operational:

| Phase | Status | Description |
|-------|--------|-------------|
| 1. Architecture | ✅ Complete | Repo structure, Docker, CI/CD, DB schema |
| 2. CAD Import | ✅ Complete | STEP/IGES/STL/BREP via OpenCASCADE (OCP) |
| 3. Feature Recognition | ✅ Complete | Holes, counterbores, countersinks, fillets, chamfers, pockets, slots, steps, shoulders, bosses |
| 4. Drawing Analysis | ✅ Complete | PDF/DXF parsing, dimensions, GD&T, title block, OCR |
| 5. Cross-Validation | ✅ Complete | Model vs drawing discrepancy detection |
| 6. CNC Analysis | ✅ Complete | Setup planning, operations, time & cost estimation |
| 7. Materials & Pricing | ✅ Complete | 10 materials, regional pricing, stock estimation |
| 8. LLM Integration | ✅ Complete | NVIDIA NIM Nemotron 3.5, privacy controls |
| 9. Flutter Frontend | ✅ Complete | All screens, responsive, light/dark theme |
| 10. Build & CI | ✅ Complete | All 6 platforms, GitHub Actions |

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flutter Frontend (JobEval)                 │
│  Dashboard │ Upload │ 3D Viewer │ Features │ Drawing            │
│  CNC │ Materials │ Cost │ Reports │ Settings │ AI Chat           │
└─────────────────────────────────────────────────────────────────┘
                             │ REST API + WebSocket
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Python FastAPI Backend                      │
│  CAD API │ Drawing API │ CNC API │ Materials API │ LLM API      │
│  Jobs API │ Reports API                                                        │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
              PostgreSQL              Redis + Celery
              (Projects)              (Task Queue)
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
              MinIO/S3              Feature Recognizer
              (File Storage)        (OpenCASCADE OCP)
```

## 🚀 Quick Start

### Prerequisites

- Python 3.11+
- Flutter 3.22+
- Docker & Docker Compose (optional)

### Option 1: Docker (Recommended)

```bash
# Clone repository
git clone <repo-url>
cd jobeval

# Copy environment file
cp .env.example .env
# Edit .env with your NVIDIA NIM API key:
#   LLM_API_KEY=nvapi-your-key
#   LLM_MODEL=nvidia/nemotron-3.5-...

# Start all services
docker-compose up -d

# Access points:
#   Frontend: http://localhost:3000
#   Backend API: http://localhost:8000
#   API Docs: http://localhost:8000/docs
#   MinIO Console: http://localhost:9001
#   Flower Monitor: http://localhost:5555
```

### Option 2: Local Development

#### Backend

```bash
cd jobeval/backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

pip install -e ".[dev]"
pip install pythonocc-core  # Install via conda if needed

cp ../.env.example .env
# Edit .env with your settings

# Start PostgreSQL, Redis, MinIO (via docker-compose or manually)
docker-compose up -d postgres redis minio

alembic upgrade head

python -m app.main

# Start Celery workers (separate terminals)
celery -A app.core.celery_app worker -Q cad_processing -l INFO
celery -A app.core.celery_app worker -Q drawing_processing -l INFO
celery -A app.core.celery_app worker -Q manufacturing -l INFO
celery -A app.core.celery_app worker -Q llm -l INFO
```

#### Frontend

```bash
cd jobeval/frontend
flutter pub get
flutter run -d chrome    # Web
flutter run -d windows   # Windows
flutter run -d linux     # Linux
flutter run -d macos     # macOS
flutter run -d android   # Android
flutter run -d ios       # iOS (macOS only)
```

### Build Commands

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release

# Web
flutter build web --release --web-renderer canvaskit
```

## 📱 Features

### Dashboard
- Project overview with status indicators
- Quick upload and recent projects
- Responsive grid layout

### CAD Upload
- Multi-file upload (STEP, IGES, STL, BREP, DXF, DWG, PDF, PNG, JPG)
- Project creation with name and description
- Upload progress tracking

### 3D CAD Viewer
- WebGL-based 3D model viewing
- Orthographic views (Top, Front, Right, Isometric)
- Camera controls (reset, pan, zoom, rotate)

### Feature Recognition
- Detected features with confidence scores
- Feature types: holes, counterbores, countersinks, fillets, chamfers, pockets, slots, steps, shoulders
- Feature grouping and pattern detection
- Filter by feature type

### Drawing Analysis
- PDF/DXF parsing
- Dimension extraction (linear, diameter, radius, thread, angular)
- GD&T symbols (flatness, position, parallelism, etc.)
- Surface finish symbols
- Title block extraction
- Notes extraction

### CNC Manufacturing Analysis
- Setup planning with orientations
- Operation mapping with tool categories
- Time estimates (cutting, setup, inspection)
- Stock dimensions and weight
- Machining difficulty rating
- Inaccessible feature warnings

### Material Database
- 10 materials (Aluminum 6061, 7075, Steel 1018/4140, SS 304/316, Brass C360, Copper C110, Delrin, Nylon 6/6)
- Material properties (density, strength, hardness)
- Regional pricing (USD with regional multipliers)
- Stock estimation from bounding box

### Cost Estimation
- Material, machining, setup, tooling, inspection, overhead costs
- Total cost breakdown
- Time breakdown (cutting, setup, tool change, inspection)
- Configurable rates

### Reports
- Technical, Executive, Manufacturing, Full report templates
- PDF, HTML, JSON export formats
- Download generated reports

### AI Chat (NVIDIA NIM Nemotron 3.5)
- Natural language queries about CAD data
- Feature explanations
- Manufacturing suggestions
- Drawing interpretation
- Privacy mode (local/approved cloud)
- Zero Data Retention support

### Settings
- Theme (Light/Dark/System)
- Privacy mode
- Backend URL configuration
- LLM provider configuration

## 🔧 Configuration

### Environment Variables (`.env`)

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection | `postgresql+asyncpg://jobeval:jobeval@localhost:5432/jobeval` |
| `REDIS_URL` | Redis connection | `redis://localhost:6379/0` |
| `STORAGE_ENDPOINT` | MinIO/S3 endpoint | `localhost:9000` |
| `LLM_PROVIDER` | LLM provider | `nvidia_nim` |
| `LLM_API_KEY` | NVIDIA NIM API key | *(required for cloud mode)* |
| `LLM_BASE_URL` | LLM API base URL | `https://integrate.api.nvidia.com/v1` |
| `LLM_MODEL` | NVIDIA Nemotron 3.5 model | `nvidia/nemotron-3.5-...` |
| `PRIVACY_MODE` | local or approved_cloud | `local` |
| `OCCT_TOLERANCE` | Geometry tolerance | `1e-6` |

## 🔒 Privacy & Security

- **Local mode**: All CAD processing stays on your machine
- **Approved cloud mode**: Only send data to explicitly enabled providers
- **Zero Data Retention**: NVIDIA NIM ZDR header support
- **No API keys in frontend**: Keys stored securely on backend only
- **Encrypted file storage**: MinIO with access keys
- **Configurable file deletion**: Auto-delete after retention period

## 📊 CAD Specs JSON Schema

The core output format is `cad_specs.json` v1.0. Key sections:

- `source_files` — Uploaded file metadata
- `geometry_summary` — Bodies, faces, volume, bbox, center of mass
- `features` — Manufacturing features with IDs, types, dimensions, confidence
- `feature_relationships` — Patterns, containment, shared axes/planes
- `drawing_annotations` — Extracted dimensions, GD&T, notes, title block
- `cross_validation` — Model vs drawing comparison
- `manufacturing_analysis` — Setups, operations, time estimates
- `material` / `cost_estimate` — Material spec and pricing
- `confidence_report` — Overall confidence and data gaps

JSON Schema available at: `backend/app/schemas/json_schema/cad_specs.schema.json`

## 🧪 Testing

```bash
# Backend tests
cd backend
pytest -v --cov=app

# Frontend tests
cd frontend
flutter test

# Integration tests
docker-compose -f docker-compose.yml up --abort-on-container-exit
```

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

---

**JobEval** — Making CNC manufacturing estimation intelligent, accurate, and accessible.