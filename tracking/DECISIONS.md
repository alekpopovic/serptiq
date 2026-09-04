# Implementation Decisions

Record temporary implementation decisions here when they do not yet justify an ADR.

| Date (UTC) | Prompt | Decision | Rationale | Revisit trigger |
|---|---:|---|---|---|
| 2026-09-04 | 005 | Enforce the union of the architecture blueprint and Prompt 002 module catalogs. | `Plans`, `Verification`, `Analysis` and `SearchData` were documented capabilities but absent from the first checker configuration, allowing future code in those folders to bypass dependency checks. | A replacement ADR changes module ownership or naming. |
| 2026-09-04 | 005 | Keep generated local storage and development in-process adapters explicitly pre-production. | ADR 0002 and 0005 remain accepted, but Prompts 007 and 070 still own full Solid topology and S3 artifact integration; the current repository must not be represented as production-ready. | Prompts 007 and 070 complete and verify their respective runtime paths. |
