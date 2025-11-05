import { PublicKey, clusterApiUrl } from "@solana/web3.js";
import * as dotenv from "dotenv";

// Load environment variables
dotenv.config();

export interface DonationConfig {
  network: "devnet" | "testnet" | "mainnet-beta" | "localnet";
  rpcUrl: string;
  wsUrl?: string;
  programId: PublicKey;
  adminKeypairPath?: string;
  minDonationAmount: number;
  maxDonationAmount: number;
  enableMonitoring: boolean;
  logLevel: "debug" | "info" | "warn" | "error";
  skipPreflight: boolean;
  maxRetries: number;
  enableAnalytics: boolean;
  enableEvents: boolean;
}

/**
 * Load configuration from environment variables
 */
export function loadConfig(): DonationConfig {
  const network = (process.env.SOLANA_NETWORK || "devnet") as DonationConfig["network"];

  // Determine RPC URL
  let rpcUrl = process.env.RPC_URL || process.env.ANCHOR_PROVIDER_URL;
  if (!rpcUrl) {
    rpcUrl = clusterApiUrl(network);
  }

  // Parse program ID
  const programIdStr = process.env.PROGRAM_ID || "DoNaT1on1111111111111111111111111111111111111";
  const programId = new PublicKey(programIdStr);

  // Parse donation limits
  const minDonationAmount = parseInt(process.env.MIN_DONATION_AMOUNT || "1000000", 10);
  const maxDonationAmount = parseInt(process.env.MAX_DONATION_AMOUNT || "100000000000", 10);

  // Parse boolean flags
  const enableMonitoring = process.env.ENABLE_MONITORING === "true";
  const skipPreflight = process.env.SKIP_PREFLIGHT === "true";
  const enableAnalytics = process.env.ENABLE_ANALYTICS === "true";
  const enableEvents = process.env.ENABLE_EVENTS !== "false"; // Default true

  // Parse other settings
  const logLevel = (process.env.LOG_LEVEL || "info") as DonationConfig["logLevel"];
  const maxRetries = parseInt(process.env.MAX_RETRIES || "3", 10);

  return {
    network,
    rpcUrl,
    wsUrl: process.env.WS_URL,
    programId,
    adminKeypairPath: process.env.ADMIN_KEYPAIR_PATH,
    minDonationAmount,
    maxDonationAmount,
    enableMonitoring,
    logLevel,
    skipPreflight,
    maxRetries,
    enableAnalytics,
    enableEvents,
  };
}

/**
 * Validate configuration
 */
export function validateConfig(config: DonationConfig): void {
  if (!config.programId) {
    throw new Error("Program ID is required");
  }

  if (config.minDonationAmount <= 0) {
    throw new Error("Minimum donation amount must be greater than 0");
  }

  if (config.maxDonationAmount <= config.minDonationAmount) {
    throw new Error("Maximum donation amount must be greater than minimum");
  }

  if (!["devnet", "testnet", "mainnet-beta", "localnet"].includes(config.network)) {
    throw new Error(`Invalid network: ${config.network}`);
  }

  if (!config.rpcUrl) {
    throw new Error("RPC URL is required");
  }
}

/**
 * Get configuration with validation
 */
export function getConfig(): DonationConfig {
  const config = loadConfig();
  validateConfig(config);
  return config;
}

/**
 * Network-specific configurations
 */
export const NETWORK_CONFIGS = {
  devnet: {
    rpcUrl: clusterApiUrl("devnet"),
    wsUrl: "wss://api.devnet.solana.com",
    confirmationCommitment: "confirmed" as const,
  },
  testnet: {
    rpcUrl: clusterApiUrl("testnet"),
    wsUrl: "wss://api.testnet.solana.com",
    confirmationCommitment: "confirmed" as const,
  },
  "mainnet-beta": {
    rpcUrl: clusterApiUrl("mainnet-beta"),
    wsUrl: "wss://api.mainnet-beta.solana.com",
    confirmationCommitment: "finalized" as const,
  },
  localnet: {
    rpcUrl: "http://127.0.0.1:8899",
    wsUrl: "ws://127.0.0.1:8900",
    confirmationCommitment: "confirmed" as const,
  },
};

/**
 * Get network-specific configuration
 */
export function getNetworkConfig(network: DonationConfig["network"]) {
  return NETWORK_CONFIGS[network];
}

/**
 * Tier thresholds (in lamports)
 */
export const TIER_THRESHOLDS = {
  BRONZE: 1_000_000, // 0.001 SOL
  SILVER: 100_000_000, // 0.1 SOL
  GOLD: 1_000_000_000, // 1 SOL
  PLATINUM: 10_000_000_000, // 10 SOL
};

/**
 * Default donation limits (in lamports)
 */
export const DEFAULT_LIMITS = {
  MIN_DONATION: 1_000_000, // 0.001 SOL
  MAX_DONATION: 100_000_000_000, // 100 SOL
};

/**
 * Export singleton instance
 */
export const config = getConfig();
