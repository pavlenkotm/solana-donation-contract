import { Connection, PublicKey } from "@solana/web3.js";
import { Program, AnchorProvider } from "@coral-xyz/anchor";
import { Donation } from "../target/types/donation";
import { DonationEvent, WithdrawEvent, VaultStatistics } from "../types";

/**
 * Monitoring configuration
 */
export interface MonitorConfig {
  pollInterval?: number; // in milliseconds
  enableLogging?: boolean;
  webhookUrl?: string;
}

/**
 * Monitoring statistics
 */
export interface MonitoringStats {
  totalDonations: number;
  totalDonationsSol: number;
  totalWithdrawals: number;
  totalWithdrawalsSol: number;
  currentBalance: number;
  currentBalanceSol: number;
  uniqueDonors: number;
  averageDonation: number;
  largestDonation: number;
  lastUpdateTimestamp: number;
}

/**
 * Event monitor for donation contract
 */
export class DonationMonitor {
  private connection: Connection;
  private program: Program<Donation>;
  private vaultStatePDA: PublicKey;
  private vaultPDA: PublicKey;
  private config: Required<MonitorConfig>;
  private isRunning: boolean = false;
  private intervalId?: NodeJS.Timeout;

  constructor(
    connection: Connection,
    program: Program<Donation>,
    vaultStatePDA: PublicKey,
    vaultPDA: PublicKey,
    config: MonitorConfig = {}
  ) {
    this.connection = connection;
    this.program = program;
    this.vaultStatePDA = vaultStatePDA;
    this.vaultPDA = vaultPDA;
    this.config = {
      pollInterval: config.pollInterval || 10000, // 10 seconds default
      enableLogging: config.enableLogging ?? true,
      webhookUrl: config.webhookUrl || "",
    };
  }

  /**
   * Start monitoring
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      this.log("Monitor is already running");
      return;
    }

    this.isRunning = true;
    this.log("Starting donation monitor...");

    // Initial fetch
    await this.checkVaultState();

    // Set up polling
    this.intervalId = setInterval(async () => {
      try {
        await this.checkVaultState();
      } catch (error) {
        this.log(`Error checking vault state: ${error}`, "error");
      }
    }, this.config.pollInterval);

    // Listen to donation events
    this.listenToDonationEvents();
    this.listenToWithdrawEvents();

    this.log("Monitor started successfully");
  }

  /**
   * Stop monitoring
   */
  stop(): void {
    if (!this.isRunning) {
      return;
    }

    if (this.intervalId) {
      clearInterval(this.intervalId);
    }

    this.isRunning = false;
    this.log("Monitor stopped");
  }

  /**
   * Check current vault state
   */
  private async checkVaultState(): Promise<VaultStatistics> {
    const vaultState = await this.program.account.vaultState.fetch(this.vaultStatePDA);
    const vaultAccount = await this.connection.getAccountInfo(this.vaultPDA);

    const stats: VaultStatistics = {
      admin: vaultState.admin,
      totalDonated: vaultState.totalDonated.toNumber(),
      totalDonatedSOL: vaultState.totalDonated.toNumber() / 1e9,
      totalWithdrawn: vaultState.totalWithdrawn.toNumber(),
      totalWithdrawnSOL: vaultState.totalWithdrawn.toNumber() / 1e9,
      currentBalance: vaultAccount?.lamports || 0,
      currentBalanceSOL: (vaultAccount?.lamports || 0) / 1e9,
      donationCount: vaultState.donationCount.toNumber(),
      uniqueDonors: vaultState.uniqueDonors.toNumber(),
      isPaused: vaultState.isPaused,
      minDonationAmount: vaultState.minDonationAmount.toNumber(),
      minDonationAmountSOL: vaultState.minDonationAmount.toNumber() / 1e9,
      maxDonationAmount: vaultState.maxDonationAmount.toNumber(),
      maxDonationAmountSOL: vaultState.maxDonationAmount.toNumber() / 1e9,
    };

    this.log(`Vault State: ${stats.donationCount} donations, ${stats.currentBalanceSol.toFixed(4)} SOL`);

    return stats;
  }

  /**
   * Listen to donation events
   */
  private listenToDonationEvents(): void {
    this.program.addEventListener("DonationEvent", (event, slot) => {
      const donationEvent: DonationEvent = {
        donor: event.donor,
        amount: event.amount,
        amountSOL: event.amount.toNumber() / 1e9,
        totalDonated: event.totalDonated,
        donorTier: this.parseTier(event.donorTier),
        timestamp: Date.now(),
      };

      this.log(`🎉 New Donation: ${donationEvent.amountSOL.toFixed(4)} SOL from ${event.donor.toString().slice(0, 8)}...`);
      this.onDonation(donationEvent);
    });
  }

  /**
   * Listen to withdraw events
   */
  private listenToWithdrawEvents(): void {
    this.program.addEventListener("WithdrawEvent", (event, slot) => {
      const withdrawEvent: WithdrawEvent = {
        admin: event.admin,
        amount: event.amount,
        amountSOL: event.amount.toNumber() / 1e9,
        timestamp: Date.now(),
      };

      this.log(`💸 Withdrawal: ${withdrawEvent.amountSOL.toFixed(4)} SOL to ${event.admin.toString().slice(0, 8)}...`);
      this.onWithdraw(withdrawEvent);
    });
  }

  /**
   * Handle donation event
   */
  private async onDonation(event: DonationEvent): Promise<void> {
    if (this.config.webhookUrl) {
      await this.sendWebhook({
        type: "donation",
        data: event,
      });
    }
  }

  /**
   * Handle withdraw event
   */
  private async onWithdraw(event: WithdrawEvent): Promise<void> {
    if (this.config.webhookUrl) {
      await this.sendWebhook({
        type: "withdraw",
        data: event,
      });
    }
  }

  /**
   * Send webhook notification
   */
  private async sendWebhook(payload: any): Promise<void> {
    if (!this.config.webhookUrl) return;

    try {
      const response = await fetch(this.config.webhookUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        this.log(`Webhook failed: ${response.statusText}`, "error");
      }
    } catch (error) {
      this.log(`Webhook error: ${error}`, "error");
    }
  }

  /**
   * Parse tier from event
   */
  private parseTier(tier: any): any {
    if (tier.bronze !== undefined) return "bronze";
    if (tier.silver !== undefined) return "silver";
    if (tier.gold !== undefined) return "gold";
    if (tier.platinum !== undefined) return "platinum";
    return "bronze";
  }

  /**
   * Log message
   */
  private log(message: string, level: "info" | "error" = "info"): void {
    if (!this.config.enableLogging) return;

    const timestamp = new Date().toISOString();
    const prefix = level === "error" ? "❌" : "ℹ️";
    console.log(`${prefix} [${timestamp}] ${message}`);
  }

  /**
   * Get current statistics
   */
  async getStats(): Promise<MonitoringStats> {
    const vaultStats = await this.checkVaultState();

    return {
      totalDonations: vaultStats.totalDonated,
      totalDonationsSol: vaultStats.totalDonatedSOL,
      totalWithdrawals: vaultStats.totalWithdrawn,
      totalWithdrawalsSol: vaultStats.totalWithdrawnSOL,
      currentBalance: vaultStats.currentBalance,
      currentBalanceSol: vaultStats.currentBalanceSOL,
      uniqueDonors: vaultStats.uniqueDonors,
      averageDonation: vaultStats.donationCount > 0
        ? vaultStats.totalDonated / vaultStats.donationCount
        : 0,
      largestDonation: 0, // Would need historical tracking
      lastUpdateTimestamp: Date.now(),
    };
  }
}

/**
 * Create a monitor instance
 */
export function createMonitor(
  connection: Connection,
  program: Program<Donation>,
  vaultStatePDA: PublicKey,
  vaultPDA: PublicKey,
  config?: MonitorConfig
): DonationMonitor {
  return new DonationMonitor(connection, program, vaultStatePDA, vaultPDA, config);
}
