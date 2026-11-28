# Security and privacy

## Reporting

Please report a suspected vulnerability privately through the repository's GitHub security advisory mechanism. Do not include confidential CAD files, drawings, credentials, or customer data in a public issue.

## Data handling

JobEval treats uploaded CAD and drawing files as confidential. The local development profile keeps the database, source files, generated meshes, and reports under an ignored runtime directory. These files are not committed to Git.

Uploaded filenames are metadata only. Storage names are generated, and file extensions/content/size are validated. The API does not intentionally expose local paths in ordinary responses.

## Optional network integrations

The core application works without a network service or API key. If an optional LLM is enabled:

- only validated structured project results are eligible for explanation;
- original CAD/drawing binaries are not sent;
- provider credentials remain in environment variables;
- generated prose is labelled and cannot modify deterministic values.

OCR and remote storage adapters must make their availability and destination visible to the user. A missing optional dependency must not silently enable another path.

## Deployment guidance

- Replace development CORS origins with explicit deployment origins.
- Use a secret manager for provider and database credentials.
- Restrict upload size and processing time/resource budgets.
- Use a production database, durable queue, and object-storage adapter when moving beyond a single local machine.
- Apply migrations rather than ad-hoc schema changes.
- Do not expose local developer error traces in ordinary user-facing responses.

JobEval has not been assessed against a formal regulatory certification. Do not represent it as compliant solely from these engineering controls.
