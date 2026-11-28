# JobEval release checklist

Use this checklist for every release candidate. Record command output and platform/tool versions in the release notes; a checked box without evidence is not sufficient.

## Source and compatibility

- [ ] Working tree contains only intended changes.
- [ ] Branch and commit are recorded.
- [ ] Python, Flutter/Dart, build123d/OCP, PyMuPDF, and ezdxf versions are recorded.
- [ ] Database migrations apply from an empty database and upgrade from the previous release.
- [ ] API/OpenAPI contract changed intentionally and the Flutter client was updated.

## Backend

- [ ] `ruff format --check app tests` passes.
- [ ] `ruff check app tests` passes.
- [ ] `pytest` passes with coverage recorded.
- [ ] Health, project, upload, analysis, job, drawing, validation, plan, pricing, estimate, and report smoke paths pass.
- [ ] Malformed, unsupported, duplicate, oversized, and traversal-oriented upload cases fail safely.
- [ ] Missing rates, missing OCR, missing LLM key, invalid CAD, and ambiguous units produce visible warnings/errors.

## Frontend

- [ ] `dart format --output=none --set-exit-if-changed lib test` passes.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] Web release build passes.
- [ ] Android build passes where the toolchain is available.
- [ ] Windows desktop build passes on a machine with the Visual Studio C++ workload.
- [ ] Offline backend, failed request, empty project, failed job, low-confidence feature, and missing-rate states are reviewed.
- [ ] Units, source/inferred/default/user-edited labels, and quote formulas are visible.

## Analysis and estimate integrity

- [ ] Known geometry fixtures meet documented dimension/volume tolerances.
- [ ] Feature fixtures include positive, negative, duplicate, and low-confidence cases.
- [ ] Drawing fixtures report extraction method and source location.
- [ ] Seeded drawing/model mismatches are detected.
- [ ] Symmetric, asymmetric, zero, and selected-blank stock cases pass.
- [ ] Quantity, line-item rounding, overrides, missing rates, and snapshot immutability pass.
- [ ] The default stock allowance is visible as 2.0 mm per side and can be set to zero.

## Privacy and security

- [ ] No API keys, customer CAD files, runtime databases, uploads, or generated reports are committed.
- [ ] CORS origins are explicit.
- [ ] Uploaded filenames never become storage paths.
- [ ] LLM use is opt-in; structured results are the only data sent.
- [ ] User-visible errors do not include stack traces.

## Documentation and release

- [ ] README commands work from a clean terminal.
- [ ] Known limitations match the implementation.
- [ ] Milestone reports contain actual outputs and screenshot paths.
- [ ] `CHANGELOG.md` describes user-visible changes.
- [ ] Version and build metadata are updated.
- [ ] Release artifacts and checksums are retained outside source control when required.
