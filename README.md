# XENØr — Sale (bonding curve prototype)

> Archived experimental sale infrastructure for earlier XENØr research. Not the current primary project surface.

 Status: archived experiment

This repository contains an early bonding-curve token sale prototype for the XENØr project.

The system was originally designed as a custom Solana mint-on-demand bonding curve sale using Anchor.
It is now kept as a research and development artifact.

## Repository contents

- Anchor sale program (mint-on-demand bonding curve) → `anchor-programs/sale`
- Next.js frontend prototype → `website`
- Scripts for mint creation and pump.fun submission → `scripts`
- Documentation and security checklist → `docs`

## Notes

This repository represents an experimental implementation that was intended for Solana mainnet deployment.

The current XENØr launch path does **not** use this contract.
The repository remains public as a development record of the bonding curve prototype.

## Warning

Do not deploy this program to mainnet without:

- a full security audit
- extensive local testing (`anchor test`)
- proper multisig and upgrade authority configuration
