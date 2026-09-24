# Inalpha Issue #165 — PR-ready analytical package

## Contents

- `FINDINGS.md` — final validation/methodology/findings document
- `sql/validation_checks.sql` — reproducible SQLite checks
- `RELATIONSHIP_MAP.md` — lineage and relationship model
- `DATA_DICTIONARY.md` — field semantics
- `METRIC_CATALOGUE.md` — metric definitions and reproducibility status
- `powerbi/DAX_MEASURES.md` — confirmed DAX measure
- `powerbi/POWER_QUERY.md` — Power Query packaging note

## Public-data boundary

Do not commit private source rows, the private workbook/PBIX, account data, internal UUIDs, credentials, or private archive data. The public PR should contain reproducible analytical logic, definitions, aggregate findings, synthetic fixtures where needed, and safe screenshots.

## Final repository step

Before opening the Draft PR, read the repository `CONTRIBUTING.md`, copy the exact final Power Query M and any additional final DAX measures from the working PBIX/model if required by the repository, run the checks against the approved equivalent sanitized dataset, and link the PR to Issue #165.
