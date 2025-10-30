# 🪙 Solana Donation Contract (Rust + Anchor)

A minimal **Solana smart contract** written in Rust using the Anchor framework.  
Users can donate lamports; the admin can withdraw the total balance.

## 🧰 Stack
- Rust + Anchor Framework
- Solana runtime (BPF)
- Events: `DonationEvent`, `WithdrawEvent`

## ⚙️ Build locally
```bash
anchor build
