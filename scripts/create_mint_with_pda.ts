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
