use anchor_lang::prelude::*;
use anchor_lang::solana_program::program::invoke;
use anchor_lang::solana_program::system_instruction;
use anchor_spl::token::{self, Burn, Mint, MintTo, Token, TokenAccount};
use std::convert::TryInto;

declare_id!("HD91U2CVgTcStNZKwE78ni2oHTYcF34wZHM2nRFKhD5K");

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
        sale.bump = ctx.bumps.sale;
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
        require!(!ctx.accounts.sale.paused, ErrorCode::SalePaused);
        require!(amount > 0, ErrorCode::InvalidAmount);

        let current_total_minted = ctx.accounts.sale.total_minted;
        let per_wallet_cap = ctx.accounts.sale.per_wallet_cap;
        let cap_total = ctx.accounts.sale.cap_total;
        let base_price = ctx.accounts.sale.base_price;
        let k = ctx.accounts.sale.k;
        let burn_bps = ctx.accounts.sale.burn_bps;
        let sale_mint = ctx.accounts.sale.mint;
        let sale_bump = ctx.accounts.sale.bump;

        let new_wallet_total = ctx
            .accounts
            .buyer_record
            .purchased
            .checked_add(amount)
            .ok_or(ErrorCode::Overflow)?;
        require!(
            new_wallet_total <= per_wallet_cap || per_wallet_cap == 0,
            ErrorCode::PerWalletCapExceeded
        );

        if cap_total > 0 {
            let new_total = current_total_minted
                .checked_add(amount)
                .ok_or(ErrorCode::Overflow)?;
            require!(new_total <= cap_total, ErrorCode::TotalCapExceeded);
        }

        let s = current_total_minted as u128;
        let n = amount as u128;
        let base = base_price as u128;
        let k = k as u128;

        let part1 = n.checked_mul(base).ok_or(ErrorCode::Overflow)?;
        let part2a = n.checked_mul(s).ok_or(ErrorCode::Overflow)?;
        let part2b = n
            .checked_mul(n.checked_sub(1).ok_or(ErrorCode::Overflow)?)
            .ok_or(ErrorCode::Overflow)?
            .checked_div(2)
            .ok_or(ErrorCode::Overflow)?;
        let total_k_mul = part2a.checked_add(part2b).ok_or(ErrorCode::Overflow)?;
        let part2 = k.checked_mul(total_k_mul).ok_or(ErrorCode::Overflow)?;
        let price_total_u128 = part1.checked_add(part2).ok_or(ErrorCode::Overflow)?;
        let price_total: u64 = price_total_u128
            .try_into()
            .map_err(|_| ErrorCode::Overflow)?;

        let ix = system_instruction::transfer(
            &ctx.accounts.buyer.key(),
            &ctx.accounts.treasury.key(),
            price_total,
        );
        invoke(
            &ix,
            &[
                ctx.accounts.buyer.to_account_info(),
                ctx.accounts.treasury.to_account_info(),
                ctx.accounts.system_program.to_account_info(),
            ],
        )?;

        ctx.accounts.sale.total_minted = current_total_minted
            .checked_add(amount)
            .ok_or(ErrorCode::Overflow)?;
        ctx.accounts.buyer_record.purchased = new_wallet_total;

        let burn_bps_u128 = burn_bps as u128;
        let burn_amount = ((amount as u128)
            .checked_mul(burn_bps_u128)
            .ok_or(ErrorCode::Overflow)?)
        .checked_div(10_000u128)
        .ok_or(ErrorCode::Overflow)? as u64;
        let mint_to_buyer = amount.checked_sub(burn_amount).ok_or(ErrorCode::Overflow)?;

        let bump_seed = [sale_bump];
        let seeds: &[&[u8]] = &[b"sale", sale_mint.as_ref(), bump_seed.as_ref()];
        let signer = &[seeds];
        let cpi_accounts_b = MintTo {
            mint: ctx.accounts.mint.to_account_info(),
            to: ctx.accounts.buyer_ata.to_account_info(),
            authority: ctx.accounts.sale.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx_b = CpiContext::new_with_signer(cpi_program.clone(), cpi_accounts_b, signer);
        if mint_to_buyer > 0 {
            token::mint_to(cpi_ctx_b, mint_to_buyer)?;
        }

        if burn_amount > 0 {
            let cpi_accounts_burn_mint = MintTo {
                mint: ctx.accounts.mint.to_account_info(),
                to: ctx.accounts.burn_ata.to_account_info(),
                authority: ctx.accounts.sale.to_account_info(),
            };
            let cpi_ctx_burn_mint =
                CpiContext::new_with_signer(cpi_program.clone(), cpi_accounts_burn_mint, signer);
            token::mint_to(cpi_ctx_burn_mint, burn_amount)?;

            let cpi_accounts_burn = Burn {
                mint: ctx.accounts.mint.to_account_info(),
                from: ctx.accounts.burn_ata.to_account_info(),
                authority: ctx.accounts.sale.to_account_info(),
            };
            let cpi_ctx_burn =
                CpiContext::new_with_signer(cpi_program.clone(), cpi_accounts_burn, signer);
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
pub struct InitializeSale<'info> {
    #[account(mut)]
    pub mint: Account<'info, Mint>,

    #[account(
        init,
        payer = admin,
        space = 8 + Sale::LEN,
        seeds = [b"sale", mint.key().as_ref()],
        bump
    )]
    pub sale: Account<'info, Sale>,

    #[account(mut)]
    pub admin: Signer<'info>,

    /// CHECK: Treasury is a lamports receiver in a system transfer.
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

    #[account(
        mut,
        seeds = [b"sale", mint.key().as_ref()],
        bump = sale.bump
    )]
    pub sale: Account<'info, Sale>,

    #[account(mut)]
    pub mint: Account<'info, Mint>,

    #[account(
        mut,
        token::mint = mint,
        token::authority = buyer
    )]
    pub buyer_ata: Account<'info, TokenAccount>,

    #[account(
        mut,
        token::mint = mint,
        token::authority = sale
    )]
    pub burn_ata: Account<'info, TokenAccount>,

    #[account(
        init_if_needed,
        payer = buyer,
        space = 8 + BuyerRecord::LEN,
        seeds = [b"buyer", buyer_ata.owner.as_ref(), mint.key().as_ref()],
        bump
    )]
    pub buyer_record: Account<'info, BuyerRecord>,

    /// CHECK: Treasury is a lamports receiver in a system transfer.
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
