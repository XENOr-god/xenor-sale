# SECURITY (must-read)

- Do NOT deploy to mainnet without external audit.
- Admin operations must be executed via Squads multisig (3/5 recommended) + timelock (48-72h).
- Keep deployer key offline. Use ephemeral keys for deploy only.
- Bug bounty recommended for at least 1-2% allocation or bounty payout.
- Reproducible builds & pinned dependencies.
- Prepare emergency pause via `pause_sale` (callable by admin).
- Monitor txs & set alerts for anomalous activity.
