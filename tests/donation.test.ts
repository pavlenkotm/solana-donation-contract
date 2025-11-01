import * as anchor from "@coral-xyz/anchor";
import { Program, BN } from "@coral-xyz/anchor";
import { Donation } from "../target/types/donation";
import { PublicKey, Keypair, LAMPORTS_PER_SOL } from "@solana/web3.js";
import { assert } from "chai";

describe("Donation Contract - Comprehensive Tests", () => {
  // Configure the client to use the local cluster
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.Donation as Program<Donation>;

  // Test accounts
  const admin = provider.wallet as anchor.Wallet;
  const donor1 = Keypair.generate();
  const donor2 = Keypair.generate();
  const donor3 = Keypair.generate();

  // PDAs
  let vaultStatePDA: PublicKey;
  let vaultPDA: PublicKey;
  let donor1InfoPDA: PublicKey;
  let donor2InfoPDA: PublicKey;
  let donor3InfoPDA: PublicKey;

  // Donation amounts
  const MIN_DONATION = new BN(1_000_000); // 0.001 SOL
  const SILVER_TIER = new BN(100_000_000); // 0.1 SOL
  const GOLD_TIER = new BN(1_000_000_000); // 1 SOL
  const PLATINUM_TIER = new BN(10_000_000_000); // 10 SOL

  before(async () => {
    // Derive PDAs
    [vaultStatePDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("vault_state")],
      program.programId
    );

    [vaultPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("vault")],
      program.programId
    );

    [donor1InfoPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("donor_info"), donor1.publicKey.toBuffer()],
      program.programId
    );

    [donor2InfoPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("donor_info"), donor2.publicKey.toBuffer()],
      program.programId
    );

    [donor3InfoPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("donor_info"), donor3.publicKey.toBuffer()],
      program.programId
    );

    // Fund test accounts
    const airdropAmount = 15 * LAMPORTS_PER_SOL;
    await provider.connection.confirmTransaction(
      await provider.connection.requestAirdrop(donor1.publicKey, airdropAmount)
    );
    await provider.connection.confirmTransaction(
      await provider.connection.requestAirdrop(donor2.publicKey, airdropAmount)
    );
    await provider.connection.confirmTransaction(
      await provider.connection.requestAirdrop(donor3.publicKey, airdropAmount)
    );

    console.log("✅ Test accounts funded");
  });

  describe("Initialization", () => {
    it("Initializes the donation vault", async () => {
      await program.methods
        .initialize()
        .accounts({
          admin: admin.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .rpc();

      const vaultState = await program.account.vaultState.fetch(vaultStatePDA);

      assert.equal(vaultState.admin.toString(), admin.publicKey.toString());
      assert.equal(vaultState.totalDonated.toNumber(), 0);
      assert.equal(vaultState.donationCount.toNumber(), 0);
      assert.equal(vaultState.isPaused, false);

      console.log("✅ Vault initialized successfully");
    });
  });

  describe("Donations", () => {
    it("Allows a valid donation (Bronze tier)", async () => {
      const donationAmount = MIN_DONATION;

      await program.methods
        .donate(donationAmount)
        .accounts({
          donor: donor1.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          donorInfo: donor1InfoPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([donor1])
        .rpc();

      const vaultState = await program.account.vaultState.fetch(vaultStatePDA);
      const donorInfo = await program.account.donorInfo.fetch(donor1InfoPDA);

      assert.equal(vaultState.totalDonated.toString(), donationAmount.toString());
      assert.equal(vaultState.donationCount.toNumber(), 1);
      assert.equal(donorInfo.totalDonated.toString(), donationAmount.toString());
      assert.equal(donorInfo.donationCount.toNumber(), 1);
      assert.deepEqual(donorInfo.tier, { bronze: {} });

      console.log("✅ Bronze tier donation successful");
    });

    it("Tracks donor tier progression (Bronze -> Silver)", async () => {
      const additionalDonation = SILVER_TIER.sub(MIN_DONATION);

      await program.methods
        .donate(additionalDonation)
        .accounts({
          donor: donor1.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          donorInfo: donor1InfoPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([donor1])
        .rpc();

      const donorInfo = await program.account.donorInfo.fetch(donor1InfoPDA);

      assert.equal(donorInfo.totalDonated.toString(), SILVER_TIER.toString());
      assert.equal(donorInfo.donationCount.toNumber(), 2);
      assert.deepEqual(donorInfo.tier, { silver: {} });

      console.log("✅ Donor progressed to Silver tier");
    });

    it("Achieves Gold tier", async () => {
      const goldDonation = GOLD_TIER;

      await program.methods
        .donate(goldDonation)
        .accounts({
          donor: donor2.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          donorInfo: donor2InfoPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([donor2])
        .rpc();

      const donorInfo = await program.account.donorInfo.fetch(donor2InfoPDA);

      assert.equal(donorInfo.totalDonated.toString(), goldDonation.toString());
      assert.deepEqual(donorInfo.tier, { gold: {} });

      console.log("✅ Gold tier achieved");
    });

    it("Achieves Platinum tier", async () => {
      const platinumDonation = PLATINUM_TIER;

      await program.methods
        .donate(platinumDonation)
        .accounts({
          donor: donor3.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          donorInfo: donor3InfoPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([donor3])
        .rpc();

      const donorInfo = await program.account.donorInfo.fetch(donor3InfoPDA);

      assert.equal(donorInfo.totalDonated.toString(), platinumDonation.toString());
      assert.deepEqual(donorInfo.tier, { platinum: {} });

      console.log("✅ Platinum tier achieved");
    });

    it("Rejects donation below minimum", async () => {
      const tooSmall = new BN(100_000); // 0.0001 SOL

      try {
        await program.methods
          .donate(tooSmall)
          .accounts({
            donor: donor1.publicKey,
            vaultState: vaultStatePDA,
            vault: vaultPDA,
            donorInfo: donor1InfoPDA,
            systemProgram: anchor.web3.SystemProgram.programId,
          })
          .signers([donor1])
          .rpc();

        assert.fail("Should have thrown error for donation too small");
      } catch (err) {
        assert.include(err.toString(), "DonationTooSmall");
        console.log("✅ Correctly rejected small donation");
      }
    });

    it("Rejects donation above maximum", async () => {
      const tooLarge = new BN(101_000_000_000); // 101 SOL

      try {
        await program.methods
          .donate(tooLarge)
          .accounts({
            donor: donor1.publicKey,
            vaultState: vaultStatePDA,
            vault: vaultPDA,
            donorInfo: donor1InfoPDA,
            systemProgram: anchor.web3.SystemProgram.programId,
          })
          .signers([donor1])
          .rpc();

        assert.fail("Should have thrown error for donation too large");
      } catch (err) {
        assert.include(err.toString(), "DonationTooLarge");
        console.log("✅ Correctly rejected large donation");
      }
    });
  });

  describe("Pause/Unpause", () => {
    it("Allows admin to pause the contract", async () => {
      await program.methods
        .pause()
        .accounts({
          admin: admin.publicKey,
          vaultState: vaultStatePDA,
        })
        .rpc();

      const vaultState = await program.account.vaultState.fetch(vaultStatePDA);
      assert.equal(vaultState.isPaused, true);

      console.log("✅ Contract paused successfully");
    });

    it("Rejects donations when paused", async () => {
      try {
        await program.methods
          .donate(MIN_DONATION)
          .accounts({
            donor: donor1.publicKey,
            vaultState: vaultStatePDA,
            vault: vaultPDA,
            donorInfo: donor1InfoPDA,
            systemProgram: anchor.web3.SystemProgram.programId,
          })
          .signers([donor1])
          .rpc();

        assert.fail("Should have thrown error for paused contract");
      } catch (err) {
        assert.include(err.toString(), "ContractPaused");
        console.log("✅ Correctly rejected donation while paused");
      }
    });

    it("Allows admin to unpause the contract", async () => {
      await program.methods
        .unpause()
        .accounts({
          admin: admin.publicKey,
          vaultState: vaultStatePDA,
        })
        .rpc();

      const vaultState = await program.account.vaultState.fetch(vaultStatePDA);
      assert.equal(vaultState.isPaused, false);

      console.log("✅ Contract unpaused successfully");
    });

    it("Prevents non-admin from pausing", async () => {
      try {
        await program.methods
          .pause()
          .accounts({
            admin: donor1.publicKey,
            vaultState: vaultStatePDA,
          })
          .signers([donor1])
          .rpc();

        assert.fail("Should have thrown error for unauthorized pause");
      } catch (err) {
        assert.include(err.toString(), "Unauthorized");
        console.log("✅ Correctly rejected non-admin pause");
      }
    });
  });

  describe("Withdrawals", () => {
    it("Allows admin to withdraw all funds", async () => {
      const vaultBalanceBefore = await provider.connection.getBalance(vaultPDA);
      const adminBalanceBefore = await provider.connection.getBalance(admin.publicKey);

      await program.methods
        .withdraw()
        .accounts({
          admin: admin.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
        })
        .rpc();

      const vaultBalanceAfter = await provider.connection.getBalance(vaultPDA);
      const adminBalanceAfter = await provider.connection.getBalance(admin.publicKey);

      assert.isBelow(vaultBalanceAfter, vaultBalanceBefore);
      assert.isAbove(adminBalanceAfter, adminBalanceBefore);

      console.log("✅ Full withdrawal successful");
    });

    it("Allows admin to make partial withdrawal", async () => {
      // First, add more funds
      await program.methods
        .donate(GOLD_TIER)
        .accounts({
          donor: donor1.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
          donorInfo: donor1InfoPDA,
          systemProgram: anchor.web3.SystemProgram.programId,
        })
        .signers([donor1])
        .rpc();

      const withdrawAmount = new BN(500_000_000); // 0.5 SOL
      const vaultBalanceBefore = await provider.connection.getBalance(vaultPDA);

      await program.methods
        .withdrawPartial(withdrawAmount)
        .accounts({
          admin: admin.publicKey,
          vaultState: vaultStatePDA,
          vault: vaultPDA,
        })
        .rpc();

      const vaultBalanceAfter = await provider.connection.getBalance(vaultPDA);

      assert.approximately(
        vaultBalanceBefore - vaultBalanceAfter,
        withdrawAmount.toNumber(),
        1000 // Allow small variance for fees
      );

      console.log("✅ Partial withdrawal successful");
    });

    it("Prevents non-admin from withdrawing", async () => {
      try {
        await program.methods
          .withdraw()
          .accounts({
            admin: donor1.publicKey,
            vaultState: vaultStatePDA,
            vault: vaultPDA,
          })
          .signers([donor1])
          .rpc();

        assert.fail("Should have thrown error for unauthorized withdrawal");
      } catch (err) {
        assert.include(err.toString(), "Unauthorized");
        console.log("✅ Correctly rejected non-admin withdrawal");
      }
    });

    it("Prevents withdrawal of invalid amount", async () => {
      try {
        await program.methods
          .withdrawPartial(new BN(0))
          .accounts({
            admin: admin.publicKey,
            vaultState: vaultStatePDA,
            vault: vaultPDA,
          })
          .rpc();

        assert.fail("Should have thrown error for zero amount");
      } catch (err) {
        assert.include(err.toString(), "InvalidAmount");
        console.log("✅ Correctly rejected zero withdrawal");
      }
    });
  });

  describe("Admin Management", () => {
    it("Allows admin to transfer ownership", async () => {
      const newAdmin = Keypair.generate();

      await program.methods
        .updateAdmin(newAdmin.publicKey)
        .accounts({
          admin: admin.publicKey,
          vaultState: vaultStatePDA,
        })
        .rpc();

      const vaultState = await program.account.vaultState.fetch(vaultStatePDA);
      assert.equal(vaultState.admin.toString(), newAdmin.publicKey.toString());

      // Transfer back to original admin
      await program.methods
        .updateAdmin(admin.publicKey)
        .accounts({
          admin: newAdmin.publicKey,
          vaultState: vaultStatePDA,
        })
        .signers([newAdmin])
        .rpc();

      const vaultStateAfter = await program.account.vaultState.fetch(vaultStatePDA);
      assert.equal(vaultStateAfter.admin.toString(), admin.publicKey.toString());

      console.log("✅ Admin transfer successful");
    });

    it("Prevents non-admin from transferring ownership", async () => {
      const newAdmin = Keypair.generate();

      try {
        await program.methods
          .updateAdmin(newAdmin.publicKey)
          .accounts({
            admin: donor1.publicKey,
            vaultState: vaultStatePDA,
          })
          .signers([donor1])
          .rpc();

        assert.fail("Should have thrown error for unauthorized admin update");
      } catch (err) {
        assert.include(err.toString(), "Unauthorized");
        console.log("✅ Correctly rejected non-admin ownership transfer");
      }
    });
  });

  describe("Statistics and Queries", () => {
    it("Tracks total donations correctly", async () => {
      const vaultState = await program.account.vaultState.fetch(vaultStatePDA);

      assert.isAbove(vaultState.totalDonated.toNumber(), 0);
      assert.isAbove(vaultState.donationCount.toNumber(), 0);

      console.log(`✅ Total donated: ${vaultState.totalDonated.toNumber() / LAMPORTS_PER_SOL} SOL`);
      console.log(`✅ Total donations: ${vaultState.donationCount.toNumber()}`);
    });

    it("Tracks individual donor statistics", async () => {
      const donor1Info = await program.account.donorInfo.fetch(donor1InfoPDA);
      const donor2Info = await program.account.donorInfo.fetch(donor2InfoPDA);
      const donor3Info = await program.account.donorInfo.fetch(donor3InfoPDA);

      assert.isAbove(donor1Info.donationCount.toNumber(), 0);
      assert.isAbove(donor2Info.donationCount.toNumber(), 0);
      assert.isAbove(donor3Info.donationCount.toNumber(), 0);

      console.log(`✅ Donor 1: ${donor1Info.totalDonated.toNumber() / LAMPORTS_PER_SOL} SOL (${JSON.stringify(donor1Info.tier)})`);
      console.log(`✅ Donor 2: ${donor2Info.totalDonated.toNumber() / LAMPORTS_PER_SOL} SOL (${JSON.stringify(donor2Info.tier)})`);
      console.log(`✅ Donor 3: ${donor3Info.totalDonated.toNumber() / LAMPORTS_PER_SOL} SOL (${JSON.stringify(donor3Info.tier)})`);
    });
  });
});
