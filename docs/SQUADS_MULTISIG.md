# Squads multisig quick guide

1. Create Squads multisig via Squads UI (https://squads.so).
2. Choose owners and threshold (e.g., 3 of 5).
3. Save multisig address -> use it as `admin` when calling initialize_sale.
4. To call program admin-only methods, initiate a Squads transaction that calls Sale program instruction.
