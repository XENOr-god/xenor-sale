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
