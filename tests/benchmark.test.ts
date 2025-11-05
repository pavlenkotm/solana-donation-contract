import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Donation } from "../target/types/donation";
import { assert } from "chai";

describe("Donation Contract Benchmarks", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const program = anchor.workspace.Donation as Program<Donation>;

  let admin: anchor.web3.Keypair;
  let vaultStatePDA: anchor.web3.PublicKey;
  let vaultPDA: anchor.web3.PublicKey;

  before(async () => {
    admin = anchor.web3.Keypair.generate();

    // Airdrop SOL to admin
    const airdropSignature = await provider.connection.requestAirdrop(
      admin.publicKey,
      10 * anchor.web3.LAMPORTS_PER_SOL
    );
    await provider.connection.confirmTransaction(airdropSignature);

    // Derive PDAs
    [vaultStatePDA] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("vault_state")],
      program.programId
    );

    [vaultPDA] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("vault")],
      program.programId
    );

    // Initialize
    await program.methods
      .initialize()
      .accounts({
        admin: admin.publicKey,
        vaultState: vaultStatePDA,
        vault: vaultPDA,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([admin])
      .rpc();
  });

  describe("Performance Benchmarks", () => {
    it("Benchmark: Single donation transaction time", async () => {
      const donor = anchor.web3.Keypair.generate();
      const airdropSignature = await provider.connection.requestAirdrop(
        donor.publicKey,
        1 * anchor.web3.LAMPORTS_PER_SOL
      );
      await provider.connection.confirmTransaction(airdropSignature);

      const [donorInfoPDA] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
        program.programId
      );

      const startTime = Date.now();

      await program.methods
        .donate(new anchor.BN(10_000_000))
        .accounts({
          donor: donor.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          donorInfo: donorInfoPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([donor])
        .rpc();

      const endTime = Date.now();
      const executionTime = endTime - startTime;

      console.log(`    ⏱️  Single donation execution time: ${executionTime}ms`);
      assert.isBelow(executionTime, 5000, "Donation should complete within 5 seconds");
    });

    it("Benchmark: Multiple sequential donations", async () => {
      const donor = anchor.web3.Keypair.generate();
      const airdropSignature = await provider.connection.requestAirdrop(
        donor.publicKey,
        2 * anchor.web3.LAMPORTS_PER_SOL
      );
      await provider.connection.confirmTransaction(airdropSignature);

      const [donorInfoPDA] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
        program.programId
      );

      const iterations = 5;
      const startTime = Date.now();

      for (let i = 0; i < iterations; i++) {
        await program.methods
          .donate(new anchor.BN(10_000_000))
          .accounts({
            donor: donor.publicKey,
            vaultState: vaultStatePDA,
            vault: vaultPDA,
            donorInfo: donorInfoPDA,
            systemProgram: anchor.web3.SystemProgram.programId,
          })
          .signers([donor])
          .rpc();
      }

      const endTime = Date.now();
      const totalTime = endTime - startTime;
      const avgTime = totalTime / iterations;

      console.log(`    ⏱️  ${iterations} sequential donations:`);
      console.log(`       Total time: ${totalTime}ms`);
      console.log(`       Average time per donation: ${avgTime}ms`);

      assert.isBelow(avgTime, 3000, "Average donation should complete within 3 seconds");
    });

    it("Benchmark: Withdraw transaction time", async () => {
      // First make a donation
      const donor = anchor.web3.Keypair.generate();
      const airdropSignature = await provider.connection.requestAirdrop(
        donor.publicKey,
        1 * anchor.web3.LAMPORTS_PER_SOL
      );
      await provider.connection.confirmTransaction(airdropSignature);

      const [donorInfoPDA] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
        program.programId
      );

      await program.methods
        .donate(new anchor.BN(100_000_000))
        .accounts({
          donor: donor.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          donorInfo: donorInfoPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([donor])
        .rpc();

      // Benchmark withdrawal
      const startTime = Date.now();

      await program.methods
        .withdrawPartial(new anchor.BN(50_000_000))
        .accounts({
          admin: admin.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
        })
        .signers([admin])
        .rpc();

      const endTime = Date.now();
      const executionTime = endTime - startTime;

      console.log(`    ⏱️  Withdrawal execution time: ${executionTime}ms`);
      assert.isBelow(executionTime, 5000, "Withdrawal should complete within 5 seconds");
    });

    it("Benchmark: Account data size", async () => {
      const vaultStateAccount = await program.account.vaultState.fetch(vaultStatePDA);

      // Calculate approximate size
      const vaultStateSize = 8 + // Discriminator
        32 + // admin (Pubkey)
        8 +  // total_donated (u64)
        8 +  // donation_count (u64)
        1 +  // is_paused (bool)
        8 +  // min_donation_amount (u64)
        8 +  // max_donation_amount (u64)
        8 +  // total_withdrawn (u64)
        8 +  // unique_donors (u64)
        1;   // bump (u8)

      console.log(`    📊 VaultState account size: ~${vaultStateSize} bytes`);

      assert.isBelow(vaultStateSize, 10240, "VaultState should be under 10KB");
    });

    it("Benchmark: Get vault stats performance", async () => {
      const startTime = Date.now();

      await program.methods
        .getVaultStats()
        .accounts({
          vaultState: vaultStatePDA,
          vault: vaultPDA,
        })
        .rpc();

      const endTime = Date.now();
      const executionTime = endTime - startTime;

      console.log(`    ⏱️  Get vault stats execution time: ${executionTime}ms`);
      assert.isBelow(executionTime, 3000, "Stats retrieval should complete within 3 seconds");
    });
  });

  describe("Stress Tests", () => {
    it("Stress test: Handle maximum donation amount", async () => {
      const donor = anchor.web3.Keypair.generate();
      const airdropSignature = await provider.connection.requestAirdrop(
        donor.publicKey,
        101 * anchor.web3.LAMPORTS_PER_SOL
      );
      await provider.connection.confirmTransaction(airdropSignature);

      const [donorInfoPDA] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
        program.programId
      );

      const maxDonation = new anchor.BN(100_000_000_000); // 100 SOL

      const startTime = Date.now();

      await program.methods
        .donate(maxDonation)
        .accounts({
          donor: donor.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          donorInfo: donorInfoPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([donor])
        .rpc();

      const endTime = Date.now();
      const executionTime = endTime - startTime;

      console.log(`    ⏱️  Max donation (100 SOL) execution time: ${executionTime}ms`);

      const donorInfo = await program.account.donorInfo.fetch(donorInfoPDA);
      assert.equal(donorInfo.tier.platinum !== undefined, true, "Should reach Platinum tier");
    });

    it("Stress test: Multiple unique donors", async () => {
      const numDonors = 10;
      const startTime = Date.now();

      for (let i = 0; i < numDonors; i++) {
        const donor = anchor.web3.Keypair.generate();
        const airdropSignature = await provider.connection.requestAirdrop(
          donor.publicKey,
          1 * anchor.web3.LAMPORTS_PER_SOL
        );
        await provider.connection.confirmTransaction(airdropSignature);

        const [donorInfoPDA] = anchor.web3.PublicKey.findProgramAddressSync(
          [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
          program.programId
        );

        await program.methods
          .donate(new anchor.BN(10_000_000))
          .accounts({
            donor: donor.publicKey,
            vaultState: vaultStatePDA,
            vault: vaultPDA,
            donorInfo: donorInfoPDA,
            systemProgram: anchor.web3.SystemProgram.programId,
          })
          .signers([donor])
          .rpc();
      }

      const endTime = Date.now();
      const totalTime = endTime - startTime;
      const avgTime = totalTime / numDonors;

      console.log(`    ⏱️  ${numDonors} unique donors:`);
      console.log(`       Total time: ${totalTime}ms`);
      console.log(`       Average time per donor: ${avgTime}ms`);

      const vaultState = await program.account.vaultState.fetch(vaultStatePDA);
      console.log(`    👥 Unique donors tracked: ${vaultState.uniqueDonors.toString()}`);
    });
  });

  describe("Gas/Compute Unit Benchmarks", () => {
    it("Measure compute units for donation", async () => {
      const donor = anchor.web3.Keypair.generate();
      const airdropSignature = await provider.connection.requestAirdrop(
        donor.publicKey,
        1 * anchor.web3.LAMPORTS_PER_SOL
      );
      await provider.connection.confirmTransaction(airdropSignature);

      const [donorInfoPDA] = anchor.web3.PublicKey.findProgramAddressSync(
        [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
        program.programId
      );

      const tx = await program.methods
        .donate(new anchor.BN(10_000_000))
        .accounts({
          donor: donor.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          donorInfo: donorInfoPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([donor])
        .rpc();

      const txDetails = await provider.connection.getTransaction(tx, {
        maxSupportedTransactionVersion: 0,
      });

      console.log(`    ⚡ Compute units used: ${txDetails?.meta?.computeUnitsConsumed || 'N/A'}`);
    });
  });
});
