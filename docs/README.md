# XENØr Sale (bonding curve) - Quickstart

WARNING: This repo is configured for MAINNET operations. Do NOT run scripts unless you understand keys, fees, and process.

1. Deploy Anchor program to mainnet:
   - Install anchor & solana cli
   - Build: `anchor build`
   - Deploy: `anchor deploy --provider.cluster mainnet`
   - Copy programId to Anchor.toml and replace placeholders.

2. Create mint and assign mint_authority to sale PDA:
   - Run scripts/create_mint_with_pda.ts (or follow CLI printed steps)
   - Use `spl-token authorize <MINT> mint <SALE_PDA>` to set authority.

3. Initialize sale:
   - Call `initialize_sale` with config (base_price, k, fees, caps).
   - Use Squads/Goki multisig as admin signer.

4. Create burn ATA for PDA:
   - `spl-token create-account <MINT> --owner <SALE_PDA> --fee-payer ~/.config/solana/mainnet-deployer.json`

5. Set metadata & submit to pump.fun (see /scripts/pumpfun_submission.md).

6. Frontend: configure .env with PROGRAM_ID, MINT_ADDRESS, SALE_PDA, TREASURY_ADDRESS, etc.
