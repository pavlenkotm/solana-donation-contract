/**
 * Donation Contract Client SDK Example
 *
 * This example demonstrates how to interact with the Solana donation contract
 * from a TypeScript/JavaScript client application.
 */

import * as anchor from "@coral-xyz/anchor";
import { Program, BN, AnchorProvider } from "@coral-xyz/anchor";
import { Donation } from "../target/types/donation";
import { PublicKey, Connection, Keypair, LAMPORTS_PER_SOL } from "@solana/web3.js";

// ============================================
// Client SDK Class
// ============================================

export class DonationClient {
  private program: Program<Donation>;
  private provider: AnchorProvider;
  private vaultStatePDA: PublicKey;
  private vaultPDA: PublicKey;

  constructor(
    connection: Connection,
    wallet: anchor.Wallet,
    programId: PublicKey
  ) {
    this.provider = new AnchorProvider(connection, wallet, {
      commitment: "confirmed",
    });
    this.program = new Program(
      require("../target/idl/donation.json"),
      programId,
      this.provider
    );

    // Derive PDAs
    [this.vaultStatePDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("vault_state")],
      this.program.programId
    );

    [this.vaultPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("vault")],
      this.program.programId
    );
  }

  /**
   * Get the donor info PDA for a specific donor
   */
  getDonorInfoPDA(donor: PublicKey): PublicKey {
    const [donorInfoPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("donor_info"), donor.toBuffer()],
      this.program.programId
    );
    return donorInfoPDA;
  }

  /**
   * Initialize the donation vault
   */
  async initialize(admin: Keypair): Promise<string> {
    const tx = await this.program.methods
      .initialize()
      .accounts({
        admin: admin.publicKey,
        vaultState: this.vaultStatePDA,
        vault: this.vaultPDA,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([admin])
      .rpc();

    console.log("✅ Vault initialized. Transaction:", tx);
    return tx;
  }

  /**
   * Make a donation
   */
  async donate(donor: Keypair, amountLamports: number | BN): Promise<string> {
    const amount = typeof amountLamports === "number" ? new BN(amountLamports) : amountLamports;
    const donorInfoPDA = this.getDonorInfoPDA(donor.publicKey);

    const tx = await this.program.methods
      .donate(amount)
      .accounts({
        donor: donor.publicKey,
        vaultState: this.vaultStatePDA,
        vault: this.vaultPDA,
        donorInfo: donorInfoPDA,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([donor])
      .rpc();

    console.log(`✅ Donated ${amount.toNumber() / LAMPORTS_PER_SOL} SOL. Transaction:`, tx);
    return tx;
  }

  /**
   * Withdraw all funds (admin only)
   */
  async withdrawAll(admin: Keypair): Promise<string> {
    const tx = await this.program.methods
      .withdraw()
      .accounts({
        admin: admin.publicKey,
        vaultState: this.vaultStatePDA,
        vault: this.vaultPDA,
      })
      .signers([admin])
      .rpc();

    console.log("✅ Withdrawal successful. Transaction:", tx);
    return tx;
  }

  /**
   * Withdraw partial amount (admin only)
   */
  async withdrawPartial(admin: Keypair, amountLamports: number | BN): Promise<string> {
    const amount = typeof amountLamports === "number" ? new BN(amountLamports) : amountLamports;

    const tx = await this.program.methods
      .withdrawPartial(amount)
      .accounts({
        admin: admin.publicKey,
        vaultState: this.vaultStatePDA,
        vault: this.vaultPDA,
      })
      .signers([admin])
      .rpc();

    console.log(`✅ Withdrew ${amount.toNumber() / LAMPORTS_PER_SOL} SOL. Transaction:`, tx);
    return tx;
  }

  /**
   * Pause the contract (admin only)
   */
  async pause(admin: Keypair): Promise<string> {
    const tx = await this.program.methods
      .pause()
      .accounts({
        admin: admin.publicKey,
        vaultState: this.vaultStatePDA,
      })
      .signers([admin])
      .rpc();

    console.log("✅ Contract paused. Transaction:", tx);
    return tx;
  }

  /**
   * Unpause the contract (admin only)
   */
  async unpause(admin: Keypair): Promise<string> {
    const tx = await this.program.methods
      .unpause()
      .accounts({
        admin: admin.publicKey,
        vaultState: this.vaultStatePDA,
      })
      .signers([admin])
      .rpc();

    console.log("✅ Contract unpaused. Transaction:", tx);
    return tx;
  }

  /**
   * Update admin (current admin only)
   */
  async updateAdmin(currentAdmin: Keypair, newAdmin: PublicKey): Promise<string> {
    const tx = await this.program.methods
      .updateAdmin(newAdmin)
      .accounts({
        admin: currentAdmin.publicKey,
        vaultState: this.vaultStatePDA,
      })
      .signers([currentAdmin])
      .rpc();

    console.log("✅ Admin updated. Transaction:", tx);
    return tx;
  }

  /**
   * Get vault state information
   */
  async getVaultState() {
    const vaultState = await this.program.account.vaultState.fetch(this.vaultStatePDA);
    return {
      admin: vaultState.admin,
      totalDonated: vaultState.totalDonated.toNumber(),
      totalDonatedSOL: vaultState.totalDonated.toNumber() / LAMPORTS_PER_SOL,
      donationCount: vaultState.donationCount.toNumber(),
      isPaused: vaultState.isPaused,
    };
  }

  /**
   * Get donor information
   */
  async getDonorInfo(donor: PublicKey) {
    const donorInfoPDA = this.getDonorInfoPDA(donor);

    try {
      const donorInfo = await this.program.account.donorInfo.fetch(donorInfoPDA);
      return {
        donor: donorInfo.donor,
        totalDonated: donorInfo.totalDonated.toNumber(),
        totalDonatedSOL: donorInfo.totalDonated.toNumber() / LAMPORTS_PER_SOL,
        donationCount: donorInfo.donationCount.toNumber(),
        lastDonationTimestamp: donorInfo.lastDonationTimestamp.toNumber(),
        tier: Object.keys(donorInfo.tier)[0], // bronze, silver, gold, or platinum
      };
    } catch (err) {
      return null; // Donor hasn't donated yet
    }
  }

  /**
   * Get vault balance
   */
  async getVaultBalance(): Promise<number> {
    const balance = await this.provider.connection.getBalance(this.vaultPDA);
    return balance;
  }

  /**
   * Get vault balance in SOL
   */
  async getVaultBalanceSOL(): Promise<number> {
    const balance = await this.getVaultBalance();
    return balance / LAMPORTS_PER_SOL;
  }

  /**
   * Listen to donation events
   */
  onDonation(callback: (event: any) => void) {
    const listener = this.program.addEventListener("donationEvent", (event, slot) => {
      callback({
        donor: event.donor,
        amount: event.amount.toNumber(),
        amountSOL: event.amount.toNumber() / LAMPORTS_PER_SOL,
        totalDonated: event.totalDonated.toNumber(),
        totalDonatedSOL: event.totalDonated.toNumber() / LAMPORTS_PER_SOL,
        donorTier: Object.keys(event.donorTier)[0],
        slot,
      });
    });
    return listener;
  }

  /**
   * Listen to withdrawal events
   */
  onWithdraw(callback: (event: any) => void) {
    const listener = this.program.addEventListener("withdrawEvent", (event, slot) => {
      callback({
        admin: event.admin,
        amount: event.amount.toNumber(),
        amountSOL: event.amount.toNumber() / LAMPORTS_PER_SOL,
        slot,
      });
    });
    return listener;
  }

  /**
   * Listen to pause events
   */
  onPause(callback: (event: any) => void) {
    const listener = this.program.addEventListener("pauseEvent", (event, slot) => {
      callback({
        admin: event.admin,
        paused: event.paused,
        slot,
      });
    });
    return listener;
  }

  /**
   * Remove event listener
   */
  async removeEventListener(listenerId: number) {
    await this.program.removeEventListener(listenerId);
  }
}

// ============================================
// Usage Example
// ============================================

async function main() {
  // Setup connection and wallet
  const connection = new Connection("http://localhost:8899", "confirmed");
  const wallet = anchor.Wallet.local();

  // Program ID (replace with your deployed program ID)
  const programId = new PublicKey("DoNaT1on111111111111111111111111111111111111");

  // Create client
  const client = new DonationClient(connection, wallet, programId);

  // Example 1: Initialize vault (only needed once)
  console.log("\n=== Initializing Vault ===");
  const adminKeypair = wallet.payer;
  // await client.initialize(adminKeypair);

  // Example 2: Get vault state
  console.log("\n=== Vault State ===");
  const vaultState = await client.getVaultState();
  console.log("Admin:", vaultState.admin.toString());
  console.log("Total Donated:", vaultState.totalDonatedSOL, "SOL");
  console.log("Donation Count:", vaultState.donationCount);
  console.log("Is Paused:", vaultState.isPaused);

  // Example 3: Make a donation
  console.log("\n=== Making Donation ===");
  const donor = Keypair.generate();

  // Fund donor (for testing)
  const airdropSig = await connection.requestAirdrop(
    donor.publicKey,
    2 * LAMPORTS_PER_SOL
  );
  await connection.confirmTransaction(airdropSig);

  // Donate 0.1 SOL
  await client.donate(donor, 0.1 * LAMPORTS_PER_SOL);

  // Example 4: Get donor info
  console.log("\n=== Donor Info ===");
  const donorInfo = await client.getDonorInfo(donor.publicKey);
  if (donorInfo) {
    console.log("Total Donated:", donorInfo.totalDonatedSOL, "SOL");
    console.log("Donation Count:", donorInfo.donationCount);
    console.log("Tier:", donorInfo.tier);
  }

  // Example 5: Get vault balance
  console.log("\n=== Vault Balance ===");
  const balance = await client.getVaultBalanceSOL();
  console.log("Current Balance:", balance, "SOL");

  // Example 6: Listen to events
  console.log("\n=== Setting Up Event Listeners ===");
  const donationListener = client.onDonation((event) => {
    console.log("🎉 New Donation!");
    console.log("  Donor:", event.donor.toString());
    console.log("  Amount:", event.amountSOL, "SOL");
    console.log("  Tier:", event.donorTier);
  });

  const withdrawListener = client.onWithdraw((event) => {
    console.log("💰 Withdrawal!");
    console.log("  Admin:", event.admin.toString());
    console.log("  Amount:", event.amountSOL, "SOL");
  });

  // Example 7: Admin operations
  if (false) { // Set to true if you're the admin
    console.log("\n=== Admin Operations ===");

    // Pause contract
    await client.pause(adminKeypair);

    // Unpause contract
    await client.unpause(adminKeypair);

    // Partial withdrawal
    await client.withdrawPartial(adminKeypair, 0.5 * LAMPORTS_PER_SOL);

    // Full withdrawal
    await client.withdrawAll(adminKeypair);

    // Transfer ownership
    const newAdmin = Keypair.generate();
    await client.updateAdmin(adminKeypair, newAdmin.publicKey);
  }

  console.log("\n✅ Example completed!");
}

// Run the example
if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

export default DonationClient;
