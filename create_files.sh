#!/usr/bin/env bash
set -e

echo "Membuat struktur folder..."
mkdir -p anchor-programs/sale/programs/sale/src
mkdir -p anchor-programs/sale/tests
mkdir -p scripts
mkdir -p website/pages
mkdir -p website/lib
mkdir -p docs
mkdir -p .github/workflows

echo "Menulis .gitignore..."
cat > .gitignore <<'GITIGNORE'
# Node
node_modules
.next
dist
.env
.env.local
.env.*.local
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Rust / Anchor
/target
**/*.rs.bk
**/Cargo.lock

# Solana / Anchor local artifacts
anchor-debug
idl
**/program/target
**/program/target/

# VSCode
.vscode/

# macOS
.DS_Store
GITIGNORE

echo "Menulis .env.example..."
cat > .env.example <<'ENVEX'
# .env.example
PROGRAM_ID=REPLACE_WITH_PROGRAM_ID
MINT_ADDRESS=REPLACE_WITH_MINT
SALE_PDA=REPLACE_WITH_SALE_PDA
TREASURY_ADDRESS=REPLACE_WITH_TREASURY_ADDR
SQUADS_PUBKEY=REPLACE_SQUADS_PUBKEY
KEYPAIR_PATH=~/.config/solana/mainnet-deployer.json
NEXT_PUBLIC_CLUSTER=https://api.mainnet-beta.solana.com
NEXT_PUBLIC_MINT_ADDRESS=REPLACE_WITH_MINT
NEXT_PUBLIC_SALE_ADDRESS=REPLACE_WITH_SALE_PDA
NEXT_PUBLIC_BASE_PRICE_LAM=50000
NEXT_PUBLIC_K_LAM=10
ENVEX

echo "Menulis README.md..."
cat > README.md <<'README'
# XENØr — Sale (bonding curve)

Repo ini berisi:
- Anchor sale program (mint-on-demand bonding curve) → `anchor-programs/sale`
- Frontend Next.js → `website`
- Scripts (mint, metadata, pump.fun submission) → `scripts`
- Docs & security checklist → `docs`

**PENTING**: Repo dan skrip ini dimaksudkan untuk MAINNET Solana. Jangan deploy tanpa audit dan pengujian lokal (`anchor test`).
README

echo "Menulis LICENSE (MIT)..."
cat > LICENSE <<'LICENSE'
MIT License

Copyright (c) 2026 XENØr

Permission is hereby granted, free of charge, to any person obtaining a copy...
LICENSE

echo "Menulis Anchor.toml..."
cat > anchor-programs/sale/Anchor.toml <<'ANCHOR'
[programs.localnet]
sale = "REPLACE_WITH_PROGRAM_ID"

[registry]
url = "https://anchor.project-serum.com"

[provider]
cluster = "mainnet"
wallet = "~/.config/solana/mainnet-deployer.json"

[workspace]
members = ["programs/sale"]
ANCHOR

echo "Menulis Cargo.toml..."
cat > anchor-programs/sale/Cargo.toml <<'CARGO'
[package]
name = "xenor-sale"
version = "0.1.0"
edition = "2021"

[lib]
name = "sale"
crate-type = ["cdylib", "lib"]

[dependencies]
anchor-lang = { version = "0.31.0", features = ["init-if-needed"] }
anchor-spl = "0.31.0"
CARGO

echo "Menulis src/lib.rs (Anchor program skeleton)."
cat > anchor-programs/sale/programs/sale/src/lib.rs <<'LIB'
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, MintTo, Burn};
use anchor_lang::solana_program::system_instruction;
use anchor_lang::solana_program::program::invoke;
use std::convert::TryInto;

declare_id!("REPLACE_WITH_PROGRAM_ID");

#[program]
pub mod sale {
    use super::*;

    pub fn initialize_sale(
        ctx: Context<InitializeSale>,
        base_price_lamports: u64,
        k_lamports: u64,
        fee_bps: u16,
        burn_bps: u16,
        per_wallet_cap: u64,
        daily_cap: u64,
        cap_total: Option<u64>,
    ) -> Result<()> {
        let sale = &mut ctx.accounts.sale;
        sale.admin = *ctx.accounts.admin.key;
        sale.mint = ctx.accounts.mint.key();
        sale.bump = *ctx.bumps.get("sale_pda").unwrap();
        sale.base_price = base_price_lamports;
        sale.k = k_lamports;
        sale.fee_bps = fee_bps;
        sale.burn_bps = burn_bps;
        sale.per_wallet_cap = per_wallet_cap;
        sale.daily_cap = daily_cap;
        sale.total_minted = 0u64;
        sale.cap_total = cap_total.unwrap_or(0);
        sale.paused = false;
        Ok(())
    }

    pub fn buy(ctx: Context<Buy>, amount: u64) -> Result<()> {
        let sale = &mut ctx.accounts.sale;
        require!(!sale.paused, ErrorCode::SalePaused);
        require!(amount > 0, ErrorCode::InvalidAmount);

        let buyer_record = &mut ctx.accounts.buyer_record;
        let new_wallet_total = buyer_record.purchased.checked_add(amount).ok_or(ErrorCode::Overflow)?;
        require!(new_wallet_total <= sale.per_wallet_cap || sale.per_wallet_cap == 0, ErrorCode::PerWalletCapExceeded);

        if sale.cap_total > 0 {
            let new_total = sale.total_minted.checked_add(amount).ok_or(ErrorCode::Overflow)?;
            require!(new_total <= sale.cap_total, ErrorCode::TotalCapExceeded);
        }

        let s = sale.total_minted as u128;
        let n = amount as u128;
        let base = sale.base_price as u128;
        let k = sale.k as u128;

        let part1 = n.checked_mul(base).ok_or(ErrorCode::Overflow)?;
        let part2a = n.checked_mul(s).ok_or(ErrorCode::Overflow)?;
        let part2b = n.checked_mul(n.checked_sub(1).ok_or(ErrorCode::Overflow)?).ok_or(ErrorCode::Overflow)?
            .checked_div(2).ok_or(ErrorCode::Overflow)?;
        let total_k_mul = part2a.checked_add(part2b).ok_or(ErrorCode::Overflow)?;
        let part2 = k.checked_mul(total_k_mul).ok_or(ErrorCode::Overflow)?;
        let price_total_u128 = part1.checked_add(part2).ok_or(ErrorCode::Overflow)?;
        let price_total: u64 = price_total_u128.try_into().map_err(|_| ErrorCode::Overflow)?;

        let ix = system_instruction::transfer(&ctx.accounts.buyer.key(), &ctx.accounts.treasury.key(), price_total);
        invoke(&ix, &[
            ctx.accounts.buyer.to_account_info(),
            ctx.accounts.treasury.to_account_info(),
            ctx.accounts.system_program.to_account_info(),
        ])?;

        sale.total_minted = sale.total_minted.checked_add(amount).ok_or(ErrorCode::Overflow)?;
        buyer_record.purchased = new_wallet_total;

        let burn_bps = sale.burn_bps as u128;
        let burn_amount = ((amount as u128).checked_mul(burn_bps).ok_or(ErrorCode::Overflow)?)
            .checked_div(10_000u128).ok_or(ErrorCode::Overflow)? as u64;
        let mint_to_buyer = amount.checked_sub(burn_amount).ok_or(ErrorCode::Overflow)?;

        let seeds = &[
            b"sale",
            sale.mint.as_ref(),
            &[sale.bump],
        ];
        let signer = &[&seeds[..]];
        let cpi_accounts_b = MintTo {
            mint: ctx.accounts.mint.to_account_info(),
            to: ctx.accounts.buyer_ata.to_account_info(),
            authority: ctx.accounts.sale_pda.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx_b = CpiContext::new_with_signer(cpi_program, cpi_accounts_b, signer);
        if mint_to_buyer > 0 {
            token::mint_to(cpi_ctx_b, mint_to_buyer)?;
        }

        if burn_amount > 0 {
            let cpi_accounts_burn_mint = MintTo {
                mint: ctx.accounts.mint.to_account_info(),
                to: ctx.accounts.burn_ata.to_account_info(),
                authority: ctx.accounts.sale_pda.to_account_info(),
            };
            let cpi_ctx_burn_mint = CpiContext::new_with_signer(cpi_program, cpi_accounts_burn_mint, signer);
            token::mint_to(cpi_ctx_burn_mint, burn_amount)?;

            let cpi_accounts_burn = Burn {
                mint: ctx.accounts.mint.to_account_info(),
                from: ctx.accounts.burn_ata.to_account_info(),
                authority: ctx.accounts.sale_pda.to_account_info(),
            };
            let cpi_ctx_burn = CpiContext::new_with_signer(cpi_program, cpi_accounts_burn, signer);
            token::burn(cpi_ctx_burn, burn_amount)?;
        }

        emit!(BuyEvent {
            buyer: ctx.accounts.buyer.key(),
            amount,
            price_paid: price_total,
        });

        Ok(())
    }

    pub fn pause_sale(ctx: Context<AdminOnly>) -> Result<()> {
        let sale = &mut ctx.accounts.sale;
        sale.paused = true;
        Ok(())
    }

    pub fn resume_sale(ctx: Context<AdminOnly>) -> Result<()> {
        let sale = &mut ctx.accounts.sale;
        sale.paused = false;
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction()]
pub struct InitializeSale<'info> {
    #[account(init, payer = admin, space = 8 + Sale::LEN,
        seeds = [b"sale", mint.key().as_ref()],
        bump)]
    pub sale: Account<'info, Sale>,

    #[account(mut)]
    pub sale_pda: UncheckedAccount<'info>,

    #[account(mut)]
    pub mint: Account<'info, Mint>,

    #[account(mut)]
    pub admin: Signer<'info>,

    #[account(mut)]
    pub treasury: UncheckedAccount<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
    pub associated_token_program: Program<'info, anchor_spl::associated_token::AssociatedToken>,
}

#[derive(Accounts)]
pub struct Buy<'info> {
    #[account(mut)]
    pub buyer: Signer<'info>,

    #[account(mut, seeds = [b"sale", sale.mint.as_ref()], bump = sale.bump)]
    pub sale_pda: UncheckedAccount<'info>,

    #[account(mut)]
    pub sale: Account<'info, Sale>,

    #[account(mut)]
    pub mint: Account<'info, Mint>,

    #[account(mut, constraint = buyer_ata.owner == buyer.key())]
    pub buyer_ata: Account<'info, TokenAccount>,

    #[account(mut)]
    pub burn_ata: Account<'info, TokenAccount>,

    #[account(init_if_needed, payer = buyer, space = 8 + BuyerRecord::LEN,
        seeds = [b"buyer", buyer.key().as_ref(), sale.key().as_ref()], bump)]
    pub buyer_record: Account<'info, BuyerRecord>,

    #[account(mut)]
    pub treasury: UncheckedAccount<'info>,

    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub associated_token_program: Program<'info, anchor_spl::associated_token::AssociatedToken>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct AdminOnly<'info> {
    #[account(mut, has_one = admin)]
    pub sale: Account<'info, Sale>,
    pub admin: Signer<'info>,
}

#[account]
pub struct Sale {
    pub admin: Pubkey,
    pub mint: Pubkey,
    pub bump: u8,
    pub base_price: u64,
    pub k: u64,
    pub fee_bps: u16,
    pub burn_bps: u16,
    pub per_wallet_cap: u64,
    pub daily_cap: u64,
    pub total_minted: u64,
    pub cap_total: u64,
    pub paused: bool,
}

impl Sale {
    pub const LEN: usize = 32 + 32 + 1 + 8 + 8 + 2 + 2 + 8 + 8 + 8 + 8 + 1;
}

#[account]
pub struct BuyerRecord {
    pub purchased: u64,
}

impl BuyerRecord {
    pub const LEN: usize = 8;
}

#[error_code]
pub enum ErrorCode {
    #[msg("Sale is paused")]
    SalePaused,
    #[msg("Amount must be > 0")]
    InvalidAmount,
    #[msg("Overflow")]
    Overflow,
    #[msg("Per-wallet cap exceeded")]
    PerWalletCapExceeded,
    #[msg("Total cap exceeded")]
    TotalCapExceeded,
}

#[event]
pub struct BuyEvent {
    pub buyer: Pubkey,
    pub amount: u64,
    pub price_paid: u64,
}
LIB

echo "Menulis tests skeleton..."
cat > anchor-programs/sale/tests/sale.rs <<'TESTS'
use anchor_lang::prelude::*;
#[tokio::test]
async fn test_price_calc() -> Result<(), Box<dyn std::error::Error>> {
    // Test scaffolding to be implemented locally with solana-test-validator
    Ok(())
}
TESTS

echo "Menulis script create_mint_with_pda.ts..."
cat > scripts/create_mint_with_pda.ts <<'TS'
/* scripts/create_mint_with_pda.ts */
import { Connection, Keypair, PublicKey } from "@solana/web3.js";
import { createMint } from "@solana/spl-token";
import fs from "fs";
import path from "path";

const KEYPAIR_PATH = process.env.KEYPAIR || path.join(process.env.HOME || "~", ".config/solana/mainnet-deployer.json");
if (!process.env.PROGRAM_ID) {
  console.error("Set PROGRAM_ID env var (export PROGRAM_ID=...)");
  process.exit(1);
}
const PROGRAM_ID = new PublicKey(process.env.PROGRAM_ID);

(async () => {
  const keypair = Keypair.fromSecretKey(new Uint8Array(JSON.parse(fs.readFileSync(KEYPAIR_PATH, "utf8"))));
  const conn = new Connection("https://api.mainnet-beta.solana.com", "confirmed");

  const decimals = 9;
  const mint = await createMint(conn, keypair, keypair.publicKey, null, decimals);
  console.log("Created mint:", mint.toBase58());
  const [salePda, bump] = await PublicKey.findProgramAddress([Buffer.from("sale"), mint.toBuffer()], PROGRAM_ID);
  console.log("Sale PDA:", salePda.toBase58(), "bump:", bump);
  console.log("Now use `spl-token authorize` CLI to set mint authority to:", salePda.toBase58());
  console.log("spl-token authorize", mint.toBase58(), "mint", salePda.toBase58(), "--owner", KEYPAIR_PATH);
})();
TS

echo "Menulis pumpfun_submission.md..."
cat > scripts/pumpfun_submission.md <<'PF'
# Pump.fun Submission: XENØr (XNR)

- Mint address: REPLACE_WITH_MINT
- Name: XENØr
- Symbol: XNR
- Decimals: 9
- Website: https://your-site.example
- Twitter: https://x.com/yourhandle
- Short description: XENØr — protocol-native meme-utility token. Utility: staking, featured meme boost, creator rewards.
- Logo (arweave/ipfs): https://arweave.net/REPLACE_IMAGE_HASH
- Proof txs:
  - Mint creation tx: REPLACE_TX
  - Metadata upload tx: REPLACE_TX
  - (Optional) LP lock tx: REPLACE_TX
PF

echo "Menulis website/package.json..."
cat > website/package.json <<'PKG'
{
  "name": "xenor-website",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "@project-serum/anchor": "^0.27.0",
    "@solana/wallet-adapter-base": "^0.11.0",
    "@solana/wallet-adapter-react": "^0.18.0",
    "@solana/wallet-adapter-phantom": "^0.8.1",
    "@solana/web3.js": "^1.65.0",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "next": "13.4.4"
  }
}
PKG

echo "Menulis website/lib/solana.ts..."
cat > website/lib/solana.ts <<'SOL'
import { Connection, PublicKey } from "@solana/web3.js";

export const RPC = "https://api.mainnet-beta.solana.com";

export function calcPriceLamports(baseLam: bigint, kLam: bigint, s: bigint, n: bigint): bigint {
  const part1 = n * baseLam;
  const part2a = n * s;
  const part2b = n * (n - BigInt(1)) / BigInt(2);
  const total_k_mul = part2a + part2b;
  const part2 = kLam * total_k_mul;
  return part1 + part2;
}

export function lamportsToSol(lamports: bigint): number {
  return Number(lamports) / 1e9;
}
SOL

echo "Menulis website/pages/index.tsx..."
cat > website/pages/index.tsx <<'IDX'
import React, { useEffect, useState } from "react";
import { Connection } from "@solana/web3.js";

export default function Home() {
  const [mintAddr, setMintAddr] = useState(process.env.NEXT_PUBLIC_MINT_ADDRESS || "");
  const [saleAddr, setSaleAddr] = useState(process.env.NEXT_PUBLIC_SALE_ADDRESS || "");
  const [connection] = useState(new Connection(process.env.NEXT_PUBLIC_CLUSTER || "https://api.mainnet-beta.solana.com"));

  useEffect(() => {
    // Placeholder
  }, []);

  return (
    <div style={{ padding: 24 }}>
      <h1>XENØr (XNR) — Meme utility token</h1>
      <p>Mint: {mintAddr}</p>
      <p>Sale account: {saleAddr}</p>
      <div>
        <a href="/buy">Buy tokens</a>
      </div>
    </div>
  );
}
IDX

echo "Menulis website/pages/buy.tsx..."
cat > website/pages/buy.tsx <<'BUY'
import React, { useEffect, useState } from "react";
import { useWallet } from "@solana/wallet-adapter-react";
import { Connection } from "@solana/web3.js";
import { calcPriceLamports, lamportsToSol } from "../lib/solana";

export default function Buy() {
  const wallet = useWallet();
  const [connection] = useState(new Connection(process.env.NEXT_PUBLIC_CLUSTER || "https://api.mainnet-beta.solana.com"));
  const [amount, setAmount] = useState<number>(1);
  const [estPriceSol, setEstPriceSol] = useState<number | null>(null);

  useEffect(() => {
    async function compute() {
      const base = BigInt(Number(process.env.NEXT_PUBLIC_BASE_PRICE_LAM || "50000"));
      const k = BigInt(Number(process.env.NEXT_PUBLIC_K_LAM || "10"));
      const s = BigInt(Number(process.env.NEXT_PUBLIC_TOTAL_MINTED || "0"));
      const n = BigInt(amount);
      const total = calcPriceLamports(base, k, s, n);
      setEstPriceSol(lamportsToSol(total));
    }
    compute();
  }, [amount]);

  const handleBuy = async () => {
    if (!wallet.publicKey || !wallet.signTransaction) {
      alert("Connect Phantom first");
      return;
    }
    alert("This is a placeholder. Implement Anchor client call to `buy` with correct accounts.");
  };

  return (
    <div style={{ padding: 24 }}>
      <h2>Buy XNR</h2>
      <div>
        <label>Amount</label>
        <input type="number" min="1" value={amount} onChange={(e)=>setAmount(Number(e.target.value))}/>
      </div>
      <div>Estimated cost: {estPriceSol ? estPriceSol.toFixed(6) + " SOL" : "—"}</div>
      <button onClick={handleBuy}>Buy (mainnet)</button>
    </div>
  );
}
BUY

echo "Menulis docs..."
cat > docs/README.md <<'DREAD'
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
DREAD

cat > docs/SECURITY.md <<'DSEC'
# SECURITY (must-read)

- Do NOT deploy to mainnet without external audit.
- Admin operations must be executed via Squads multisig (3/5 recommended) + timelock (48-72h).
- Keep deployer key offline. Use ephemeral keys for deploy only.
- Bug bounty recommended for at least 1-2% allocation or bounty payout.
- Reproducible builds & pinned dependencies.
- Prepare emergency pause via `pause_sale` (callable by admin).
- Monitor txs & set alerts for anomalous activity.
DSEC

cat > docs/SQUADS_MULTISIG.md <<'DSQUADS'
# Squads multisig quick guide

1. Create Squads multisig via Squads UI (https://squads.so).
2. Choose owners and threshold (e.g., 3 of 5).
3. Save multisig address -> use it as `admin` when calling initialize_sale.
4. To call program admin-only methods, initiate a Squads transaction that calls Sale program instruction.
DSQUADS

echo "Menulis GitHub Actions skeleton..."
cat > .github/workflows/anchor-tests.yml <<'GHWF'
name: Anchor tests

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      - name: Install solana
        run: |
          sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
          export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
      - name: Install Anchor
        run: |
          npm i -g @project-serum/anchor-cli
      - name: Run anchor tests
        run: |
          cd anchor-programs/sale
          anchor test
GHWF

echo "Menulis CODEOWNERS..."
cat > .github/CODEOWNERS <<'CODEOWN'
* @XENOr-god
CODEOWN

echo "Selesai membuat file skeleton."
