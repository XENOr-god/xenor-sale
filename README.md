# xenor-sale

`xenor-sale` is an archived Solana sale prototype kept as historical XENOr
research. It is public so prior launch-path exploration remains inspectable,
not because it is the active product, infrastructure, or recommended starting
point.

## Status

Archived / historical only. This repository is not the current XENOr launch
path and should not be treated as active infrastructure.

## Why This Repo Exists

This repository exists as a record of earlier sale and launch experiments:

- Anchor-based sale program prototypes
- legacy website flows
- operational scripts
- notes, checklists, and security guidance

Keeping it public preserves context without mixing historical launch work into
the active XENOr stack.

## Relationship to the XENOr Stack

- `xenor-site` is the canonical public surface for the active stack
- `xenor-core` is the active deterministic execution/core systems layer
- `xenor-sim` is the active scenario and validation layer
- `xenor-engine` is the active deterministic engine and replay/snapshot
  substrate
- `xenor-sale` is historical only

## Quick Start / Local Inspection

There is no recommended active development path in this repository.

If you need to inspect historical work:

- review [`docs/`](docs) first for context and security notes
- inspect [`anchor-programs/sale`](anchor-programs/sale) as a prototype, not a
  production-ready program
- inspect [`website`](website) only as a legacy frontend record

Do not deploy or reuse this repository without a fresh audit, new operational
controls, and explicit governance decisions.

## Repository Boundaries / Non-goals

- This is not the canonical public surface. Use `xenor-site` instead.
- This is not current launch infrastructure.
- This is not a maintained Solana program.
- This is not a substitute for active protocol, simulation, or engine work.

## Related Repositories

- [`xenor-site`](https://github.com/XENOr-god/xenor-site) — canonical public
  surface and repository map
- [`xenor-core`](https://github.com/XENOr-god/xenor-core) — active deterministic
  execution/core systems layer
- [`xenor-sim`](https://github.com/XENOr-god/xenor-sim) — active scenario and
  validation layer
- [`xenor-engine`](https://github.com/XENOr-god/xenor-engine) — active
  deterministic engine and replay/snapshot substrate

## License

See the repository [LICENSE](LICENSE).
