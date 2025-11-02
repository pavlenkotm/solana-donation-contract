/**
 * Advanced Usage Examples for Solana Donation Contract
 *
 * This file demonstrates advanced features including:
 * - Configurable donation limits
 * - Emergency withdrawals
 * - Statistics retrieval
 * - Event monitoring
 * - Error handling
 */

import * as anchor from "@coral-xyz/anchor";
import { Program, BN } from "@coral-xyz/anchor";
import { PublicKey, Keypair, LAMPORTS_PER_SOL } from "@solana/web3.js";
import { Donation } from "../target/types/donation";

// ============================================================================
// Example 1: Setting Up Custom Donation Limits
// ============================================================================

async function setupCustomLimits(
    program: Program<Donation>,
    admin: Keypair,
    vaultStatePDA: PublicKey
) {
    console.log("\n📋 Example 1: Setting Custom Donation Limits");
    console.log("=" .repeat(60));

    // Define custom limits
    const minDonation = new BN(0.0005 * LAMPORTS_PER_SOL);  // 0.0005 SOL
    const maxDonation = new BN(50 * LAMPORTS_PER_SOL);      // 50 SOL

    console.log(`Setting limits: ${minDonation.toNumber() / LAMPORTS_PER_SOL} - ${maxDonation.toNumber() / LAMPORTS_PER_SOL} SOL`);

    try {
        // Set up event listener
        const listener = program.addEventListener(
            "DonationLimitsUpdatedEvent",
            (event) => {
                console.log("\n🔔 Limits Updated Event:");
                console.log(`  Admin: ${event.admin}`);
                console.log(`  Old Min: ${event.oldMinAmount.toNumber() / LAMPORTS_PER_SOL} SOL`);
                console.log(`  Old Max: ${event.oldMaxAmount.toNumber() / LAMPORTS_PER_SOL} SOL`);
                console.log(`  New Min: ${event.newMinAmount.toNumber() / LAMPORTS_PER_SOL} SOL`);
                console.log(`  New Max: ${event.newMaxAmount.toNumber() / LAMPORTS_PER_SOL} SOL`);
            }
        );

        // Update limits
        const tx = await program.methods
            .updateDonationLimits(minDonation, maxDonation)
            .accounts({
                admin: admin.publicKey,
                vaultState: vaultStatePDA,
            })
            .signers([admin])
            .rpc();

        console.log(`✅ Transaction confirmed: ${tx}`);

        // Verify the update
        const vaultState = await program.account.vaultState.fetch(vaultStatePDA);
        console.log("\n📊 Updated Vault State:");
        console.log(`  Min Amount: ${vaultState.minDonationAmount.toNumber() / LAMPORTS_PER_SOL} SOL`);
        console.log(`  Max Amount: ${vaultState.maxDonationAmount.toNumber() / LAMPORTS_PER_SOL} SOL`);

        // Clean up listener
        program.removeEventListener(listener);

    } catch (error) {
        console.error("❌ Error:", error);
        throw error;
    }
}

// ============================================================================
// Example 2: Monitoring Donations with Real-time Statistics
// ============================================================================

async function monitorDonationsWithStats(
    program: Program<Donation>,
    vaultStatePDA: PublicKey,
    vaultPDA: PublicKey
) {
    console.log("\n📊 Example 2: Real-time Donation Monitoring");
    console.log("=" .repeat(60));

    // Set up donation event listener
    const donationListener = program.addEventListener(
        "DonationEvent",
        async (event) => {
            console.log("\n🎉 New Donation!");
            console.log(`  Donor: ${event.donor}`);
            console.log(`  Amount: ${event.amount.toNumber() / LAMPORTS_PER_SOL} SOL`);
            console.log(`  Total Donated: ${event.totalDonated.toNumber() / LAMPORTS_PER_SOL} SOL`);
            console.log(`  Donor Tier: ${JSON.stringify(event.donorTier)}`);

            // Get updated statistics
            await getVaultStatistics(program, vaultStatePDA, vaultPDA);
        }
    );

    console.log("👂 Listening for donations... (Press Ctrl+C to stop)");

    // Keep the listener active
    await new Promise((resolve) => setTimeout(resolve, 60000)); // Listen for 1 minute

    // Clean up
    program.removeEventListener(donationListener);
}

// ============================================================================
// Example 3: Getting Comprehensive Vault Statistics
// ============================================================================

async function getVaultStatistics(
    program: Program<Donation>,
    vaultStatePDA: PublicKey,
    vaultPDA: PublicKey
) {
    console.log("\n📈 Example 3: Vault Statistics");
    console.log("=" .repeat(60));

    try {
        // Set up stats event listener
        const listener = program.addEventListener(
            "VaultStatsEvent",
            (event) => {
                const stats = event.stats;
                console.log("\n📊 Vault Statistics:");
                console.log(`  Admin: ${stats.admin}`);
                console.log(`  Total Donated: ${stats.totalDonated.toNumber() / LAMPORTS_PER_SOL} SOL`);
                console.log(`  Total Withdrawn: ${stats.totalWithdrawn.toNumber() / LAMPORTS_PER_SOL} SOL`);
                console.log(`  Current Balance: ${stats.currentBalance.toNumber() / LAMPORTS_PER_SOL} SOL`);
                console.log(`  Donation Count: ${stats.donationCount.toNumber()}`);
                console.log(`  Unique Donors: ${stats.uniqueDonors.toNumber()}`);
                console.log(`  Is Paused: ${stats.isPaused}`);
                console.log(`  Min Donation: ${stats.minDonationAmount.toNumber() / LAMPORTS_PER_SOL} SOL`);
                console.log(`  Max Donation: ${stats.maxDonationAmount.toNumber() / LAMPORTS_PER_SOL} SOL`);

                // Calculate additional metrics
                const avgDonation = stats.donationCount.toNumber() > 0
                    ? stats.totalDonated.toNumber() / stats.donationCount.toNumber() / LAMPORTS_PER_SOL
                    : 0;
                const netBalance = stats.totalDonated.toNumber() - stats.totalWithdrawn.toNumber();

                console.log(`\n📈 Derived Metrics:`);
                console.log(`  Average Donation: ${avgDonation.toFixed(4)} SOL`);
                console.log(`  Net Balance: ${netBalance / LAMPORTS_PER_SOL} SOL`);
            }
        );

        // Fetch statistics
        await program.methods
            .getVaultStats()
            .accounts({
                vaultState: vaultStatePDA,
                vault: vaultPDA,
            })
            .rpc();

        // Clean up
        await new Promise((resolve) => setTimeout(resolve, 1000));
        program.removeEventListener(listener);

    } catch (error) {
        console.error("❌ Error fetching statistics:", error);
        throw error;
    }
}

// ============================================================================
// Example 4: Emergency Withdrawal Scenarios
// ============================================================================

async function emergencyWithdrawalScenarios(
    program: Program<Donation>,
    admin: Keypair,
    vaultStatePDA: PublicKey,
    vaultPDA: PublicKey
) {
    console.log("\n🚨 Example 4: Emergency Withdrawal Scenarios");
    console.log("=" .repeat(60));

    try {
        // Scenario 1: Partial emergency withdrawal
        console.log("\n📍 Scenario 1: Partial Emergency Withdrawal");
        const partialAmount = new BN(1 * LAMPORTS_PER_SOL);

        const listener = program.addEventListener(
            "EmergencyWithdrawEvent",
            (event) => {
                console.log("\n🚨 Emergency Withdrawal Event:");
                console.log(`  Admin: ${event.admin}`);
                console.log(`  Amount: ${event.amount.toNumber() / LAMPORTS_PER_SOL} SOL`);
                console.log(`  Reason: ${event.reason}`);
            }
        );

        const tx1 = await program.methods
            .emergencyWithdraw(partialAmount)
            .accounts({
                admin: admin.publicKey,
                vaultState: vaultStatePDA,
                vault: vaultPDA,
            })
            .signers([admin])
            .rpc();

        console.log(`✅ Partial withdrawal: ${tx1}`);

        // Scenario 2: Full emergency withdrawal (amount = 0)
        console.log("\n📍 Scenario 2: Full Emergency Withdrawal");

        const tx2 = await program.methods
            .emergencyWithdraw(new BN(0))  // 0 means all funds
            .accounts({
                admin: admin.publicKey,
                vaultState: vaultStatePDA,
                vault: vaultPDA,
            })
            .signers([admin])
            .rpc();

        console.log(`✅ Full withdrawal: ${tx2}`);

        // Clean up
        await new Promise((resolve) => setTimeout(resolve, 1000));
        program.removeEventListener(listener);

    } catch (error) {
        console.error("❌ Error during emergency withdrawal:", error);
        throw error;
    }
}

// ============================================================================
// Example 5: Handling Different Donor Tiers
// ============================================================================

async function demonstrateTierSystem(
    program: Program<Donation>,
    donors: Keypair[],
    vaultStatePDA: PublicKey,
    vaultPDA: PublicKey
) {
    console.log("\n🏆 Example 5: Donor Tier System");
    console.log("=" .repeat(60));

    const tierAmounts = {
        bronze: new BN(0.001 * LAMPORTS_PER_SOL),    // Bronze tier
        silver: new BN(0.1 * LAMPORTS_PER_SOL),      // Silver tier
        gold: new BN(1 * LAMPORTS_PER_SOL),          // Gold tier
        platinum: new BN(10 * LAMPORTS_PER_SOL),     // Platinum tier
    };

    console.log("\n💰 Tier Thresholds:");
    console.log(`  🥉 Bronze: >= 0.001 SOL`);
    console.log(`  🥈 Silver: >= 0.1 SOL`);
    console.log(`  🥇 Gold: >= 1 SOL`);
    console.log(`  💎 Platinum: >= 10 SOL`);

    try {
        for (const [tierName, amount] of Object.entries(tierAmounts)) {
            const donor = donors.shift();
            if (!donor) break;

            console.log(`\n📝 Making ${tierName} tier donation (${amount.toNumber() / LAMPORTS_PER_SOL} SOL)`);

            const [donorInfoPDA] = PublicKey.findProgramAddressSync(
                [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
                program.programId
            );

            const listener = program.addEventListener(
                "DonationEvent",
                (event) => {
                    if (event.donor.equals(donor.publicKey)) {
                        console.log(`  ✅ Achieved tier: ${getTierEmoji(event.donorTier)} ${getTierName(event.donorTier)}`);
                    }
                }
            );

            await program.methods
                .donate(amount)
                .accounts({
                    donor: donor.publicKey,
                    vaultState: vaultStatePDA,
                    vault: vaultPDA,
                    donorInfo: donorInfoPDA,
                })
                .signers([donor])
                .rpc();

            await new Promise((resolve) => setTimeout(resolve, 1000));
            program.removeEventListener(listener);
        }

    } catch (error) {
        console.error("❌ Error in tier demonstration:", error);
        throw error;
    }
}

// ============================================================================
// Example 6: Error Handling and Edge Cases
// ============================================================================

async function demonstrateErrorHandling(
    program: Program<Donation>,
    donor: Keypair,
    admin: Keypair,
    vaultStatePDA: PublicKey,
    vaultPDA: PublicKey
) {
    console.log("\n⚠️  Example 6: Error Handling");
    console.log("=" .repeat(60));

    // Test 1: Donation too small
    console.log("\n📍 Test 1: Donation Too Small");
    try {
        const tinyAmount = new BN(100); // Much less than minimum
        await program.methods
            .donate(tinyAmount)
            .accounts({
                donor: donor.publicKey,
                vaultState: vaultStatePDA,
                vault: vaultPDA,
                donorInfo: PublicKey.findProgramAddressSync(
                    [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
                    program.programId
                )[0],
            })
            .signers([donor])
            .rpc();

        console.log("❌ Should have failed!");
    } catch (error: any) {
        console.log("✅ Correctly rejected: DonationTooSmall");
    }

    // Test 2: Unauthorized withdrawal
    console.log("\n📍 Test 2: Unauthorized Withdrawal");
    try {
        await program.methods
            .withdraw()
            .accounts({
                admin: donor.publicKey,  // Not the admin!
                vaultState: vaultStatePDA,
                vault: vaultPDA,
            })
            .signers([donor])
            .rpc();

        console.log("❌ Should have failed!");
    } catch (error: any) {
        console.log("✅ Correctly rejected: Unauthorized");
    }

    // Test 3: Donation when paused
    console.log("\n📍 Test 3: Donation When Paused");
    try {
        // Pause the contract
        await program.methods
            .pause()
            .accounts({
                admin: admin.publicKey,
                vaultState: vaultStatePDA,
            })
            .signers([admin])
            .rpc();

        console.log("  Contract paused");

        // Try to donate
        await program.methods
            .donate(new BN(0.01 * LAMPORTS_PER_SOL))
            .accounts({
                donor: donor.publicKey,
                vaultState: vaultStatePDA,
                vault: vaultPDA,
                donorInfo: PublicKey.findProgramAddressSync(
                    [Buffer.from("donor_info"), donor.publicKey.toBuffer()],
                    program.programId
                )[0],
            })
            .signers([donor])
            .rpc();

        console.log("❌ Should have failed!");
    } catch (error: any) {
        console.log("✅ Correctly rejected: ContractPaused");
    } finally {
        // Unpause
        await program.methods
            .unpause()
            .accounts({
                admin: admin.publicKey,
                vaultState: vaultStatePDA,
            })
            .signers([admin])
            .rpc();

        console.log("  Contract unpaused");
    }
}

// ============================================================================
// Helper Functions
// ============================================================================

function getTierName(tier: any): string {
    if (tier.bronze !== undefined) return "Bronze";
    if (tier.silver !== undefined) return "Silver";
    if (tier.gold !== undefined) return "Gold";
    if (tier.platinum !== undefined) return "Platinum";
    return "Unknown";
}

function getTierEmoji(tier: any): string {
    if (tier.bronze !== undefined) return "🥉";
    if (tier.silver !== undefined) return "🥈";
    if (tier.gold !== undefined) return "🥇";
    if (tier.platinum !== undefined) return "💎";
    return "❓";
}

// ============================================================================
// Main Execution
// ============================================================================

async function main() {
    console.log("🚀 Advanced Usage Examples - Solana Donation Contract");
    console.log("=" .repeat(60));

    // Setup (in a real scenario, these would be initialized)
    // const program = ...
    // const admin = ...
    // const donors = ...
    // const vaultStatePDA = ...
    // const vaultPDA = ...

    // Uncomment to run examples:
    // await setupCustomLimits(program, admin, vaultStatePDA);
    // await getVaultStatistics(program, vaultStatePDA, vaultPDA);
    // await emergencyWithdrawalScenarios(program, admin, vaultStatePDA, vaultPDA);
    // await demonstrateTierSystem(program, donors, vaultStatePDA, vaultPDA);
    // await demonstrateErrorHandling(program, donors[0], admin, vaultStatePDA, vaultPDA);
    // await monitorDonationsWithStats(program, vaultStatePDA, vaultPDA);
}

// Uncomment to run:
// main().catch(console.error);

export {
    setupCustomLimits,
    getVaultStatistics,
    emergencyWithdrawalScenarios,
    demonstrateTierSystem,
    demonstrateErrorHandling,
    monitorDonationsWithStats,
};
