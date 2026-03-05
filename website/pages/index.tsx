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
