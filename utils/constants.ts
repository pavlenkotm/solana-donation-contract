/**
 * Constants for donation contract
 */

import { PublicKey } from "@solana/web3.js";

/**
 * Conversion constants
 */
export const LAMPORTS_PER_SOL = 1_000_000_000;

/**
 * Default donation limits (in lamports)
 */
export const DEFAULT_MIN_DONATION = 1_000_000; // 0.001 SOL
export const DEFAULT_MAX_DONATION = 100_000_000_000; // 100 SOL

/**
 * Tier thresholds (in lamports)
 */
export const TIER_THRESHOLDS = {
  BRONZE: 1_000_000, // 0.001 SOL
  SILVER: 100_000_000, // 0.1 SOL
  GOLD: 1_000_000_000, // 1 SOL
  PLATINUM: 10_000_000_000, // 10 SOL
} as const;

/**
 * Tier names
 */
export const TIER_NAMES = {
  BRONZE: "Bronze",
  SILVER: "Silver",
  GOLD: "Gold",
  PLATINUM: "Platinum",
} as const;

/**
 * Tier emojis
 */
export const TIER_EMOJIS = {
  BRONZE: "🥉",
  SILVER: "🥈",
  GOLD: "🥇",
  PLATINUM: "💎",
} as const;

/**
 * PDA seeds
 */
export const PDA_SEEDS = {
  VAULT_STATE: "vault_state",
  VAULT: "vault",
  DONOR_INFO: "donor_info",
} as const;

/**
 * Account sizes (in bytes)
 */
export const ACCOUNT_SIZES = {
  VAULT_STATE: 8 + 32 + 8 + 8 + 1 + 8 + 8 + 8 + 8 + 1, // 90 bytes
  DONOR_INFO: 8 + 32 + 8 + 8 + 8 + 1, // 65 bytes
} as const;

/**
 * Rent exempt minimum (approximate)
 */
export const RENT_EXEMPT_MINIMUM = 890_880; // lamports for small account

/**
 * Transaction confirmation timeouts (in milliseconds)
 */
export const CONFIRMATION_TIMEOUT = {
  DEFAULT: 30_000, // 30 seconds
  FAST: 15_000, // 15 seconds
  SLOW: 60_000, // 60 seconds
} as const;

/**
 * Retry configuration
 */
export const RETRY_CONFIG = {
  MAX_RETRIES: 3,
  INITIAL_DELAY: 1000, // 1 second
  BACKOFF_MULTIPLIER: 2,
} as const;

/**
 * Network endpoints
 */
export const NETWORK_ENDPOINTS = {
  DEVNET: "https://api.devnet.solana.com",
  TESTNET: "https://api.testnet.solana.com",
  MAINNET: "https://api.mainnet-beta.solana.com",
  LOCALNET: "http://127.0.0.1:8899",
} as const;

/**
 * WebSocket endpoints
 */
export const WS_ENDPOINTS = {
  DEVNET: "wss://api.devnet.solana.com",
  TESTNET: "wss://api.testnet.solana.com",
  MAINNET: "wss://api.mainnet-beta.solana.com",
  LOCALNET: "ws://127.0.0.1:8900",
} as const;

/**
 * Commitment levels
 */
export const COMMITMENT_LEVELS = {
  PROCESSED: "processed",
  CONFIRMED: "confirmed",
  FINALIZED: "finalized",
} as const;

/**
 * Default commitment for different networks
 */
export const DEFAULT_COMMITMENT = {
  DEVNET: COMMITMENT_LEVELS.CONFIRMED,
  TESTNET: COMMITMENT_LEVELS.CONFIRMED,
  MAINNET: COMMITMENT_LEVELS.FINALIZED,
  LOCALNET: COMMITMENT_LEVELS.CONFIRMED,
} as const;

/**
 * Explorer URLs
 */
export const EXPLORER_URLS = {
  DEVNET: "https://explorer.solana.com",
  TESTNET: "https://explorer.solana.com",
  MAINNET: "https://explorer.solana.com",
} as const;

/**
 * Solscan URLs
 */
export const SOLSCAN_URLS = {
  DEVNET: "https://solscan.io",
  TESTNET: "https://solscan.io",
  MAINNET: "https://solscan.io",
} as const;

/**
 * Program IDs (update these after deployment)
 */
export const PROGRAM_IDS = {
  DEVNET: new PublicKey("DoNaT1on111111111111111111111111111111111111"),
  TESTNET: new PublicKey("DoNaT1on111111111111111111111111111111111111"),
  MAINNET: new PublicKey("DoNaT1on111111111111111111111111111111111111"),
} as const;

/**
 * System program ID
 */
export const SYSTEM_PROGRAM_ID = new PublicKey("11111111111111111111111111111111");

/**
 * Common SOL amounts (in lamports)
 */
export const COMMON_AMOUNTS = {
  "0.001 SOL": 1_000_000,
  "0.01 SOL": 10_000_000,
  "0.1 SOL": 100_000_000,
  "1 SOL": 1_000_000_000,
  "10 SOL": 10_000_000_000,
  "100 SOL": 100_000_000_000,
} as const;

/**
 * Error codes from the program
 */
export const ERROR_CODES = {
  DONATION_TOO_SMALL: 6000,
  DONATION_TOO_LARGE: 6001,
  UNAUTHORIZED: 6002,
  INSUFFICIENT_FUNDS: 6003,
  OVERFLOW: 6004,
  CONTRACT_PAUSED: 6005,
  INVALID_AMOUNT: 6006,
} as const;

/**
 * Event names
 */
export const EVENT_NAMES = {
  DONATION: "DonationEvent",
  WITHDRAW: "WithdrawEvent",
  PAUSE: "PauseEvent",
  DONATION_LIMITS_UPDATED: "DonationLimitsUpdatedEvent",
  EMERGENCY_WITHDRAW: "EmergencyWithdrawEvent",
  VAULT_STATS: "VaultStatsEvent",
} as const;

/**
 * Monitoring intervals (in milliseconds)
 */
export const MONITORING_INTERVALS = {
  FAST: 5_000, // 5 seconds
  NORMAL: 10_000, // 10 seconds
  SLOW: 30_000, // 30 seconds
} as const;

/**
 * Log levels
 */
export const LOG_LEVELS = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3,
  NONE: 4,
} as const;

/**
 * Date formats
 */
export const DATE_FORMATS = {
  ISO: "YYYY-MM-DDTHH:mm:ss.sssZ",
  SHORT: "YYYY-MM-DD",
  LONG: "YYYY-MM-DD HH:mm:ss",
} as const;

/**
 * Feature flags
 */
export const FEATURE_FLAGS = {
  ENABLE_MONITORING: true,
  ENABLE_ANALYTICS: false,
  ENABLE_EVENTS: true,
  ENABLE_WEBHOOKS: false,
} as const;

/**
 * Max values
 */
export const MAX_VALUES = {
  TOP_DONORS: 100,
  TRANSACTION_SIZE: 1232, // bytes
  ACCOUNTS_PER_TX: 64,
} as const;

/**
 * API rate limits (requests per second)
 */
export const RATE_LIMITS = {
  PUBLIC_RPC: 10,
  PAID_RPC: 100,
  PREMIUM_RPC: 1000,
} as const;

/**
 * Cache TTL (in seconds)
 */
export const CACHE_TTL = {
  SHORT: 60, // 1 minute
  MEDIUM: 300, // 5 minutes
  LONG: 3600, // 1 hour
} as const;

/**
 * Minimum SOL for account creation
 */
export const MIN_SOL_FOR_ACCOUNT = 0.00089088;

/**
 * Transaction fee estimate (in lamports)
 */
export const TX_FEE_ESTIMATE = 5_000;

/**
 * Helper function to get tier name
 */
export function getTierName(totalDonated: number): string {
  if (totalDonated >= TIER_THRESHOLDS.PLATINUM) return TIER_NAMES.PLATINUM;
  if (totalDonated >= TIER_THRESHOLDS.GOLD) return TIER_NAMES.GOLD;
  if (totalDonated >= TIER_THRESHOLDS.SILVER) return TIER_NAMES.SILVER;
  return TIER_NAMES.BRONZE;
}

/**
 * Helper function to get tier emoji
 */
export function getTierEmoji(totalDonated: number): string {
  if (totalDonated >= TIER_THRESHOLDS.PLATINUM) return TIER_EMOJIS.PLATINUM;
  if (totalDonated >= TIER_THRESHOLDS.GOLD) return TIER_EMOJIS.GOLD;
  if (totalDonated >= TIER_THRESHOLDS.SILVER) return TIER_EMOJIS.SILVER;
  return TIER_EMOJIS.BRONZE;
}

/**
 * Helper function to convert lamports to SOL
 */
export function lamportsToSOL(lamports: number): number {
  return lamports / LAMPORTS_PER_SOL;
}

/**
 * Helper function to convert SOL to lamports
 */
export function solToLamports(sol: number): number {
  return Math.floor(sol * LAMPORTS_PER_SOL);
}
