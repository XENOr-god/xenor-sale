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
