# XENØr Sale

Archived Solana bonding-curve sale prototype for the XENØr research stack.

## Status

This repository is archived. It is kept public as a research record and is not the current XENØr launch path.

## Repository Contents

- `anchor-programs/sale` — Anchor-based sale program prototype
- `website` — legacy Next.js frontend prototype
- `scripts` — operational helpers for mint and submission flow
- `docs` — notes, checklists, and security guidance

## Boundaries

- Do not treat this repository as the canonical public surface.
- Do not treat this program as production-ready.
- Prototype controls and operational assumptions require a fresh audit before any reuse.
- The current XENØr public surface lives in `xenor-site`.

## Related Repositories

- [`xenor-core`](https://github.com/XENOr-god/xenor-core) — deterministic execution layer
- [`xenor-sim`](https://github.com/XENOr-god/xenor-sim) — validation and simulation layer
- [`xenor-site`](https://github.com/XENOr-god/xenor-site) — canonical public website and repository map

## Security Note

Do not deploy this repository to mainnet without a fresh security review, local integration testing, and explicit operational controls for treasury, upgrade authority, and launch governance.
