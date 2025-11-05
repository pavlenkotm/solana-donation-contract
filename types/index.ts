import { PublicKey } from "@solana/web3.js";
import { BN } from "@coral-xyz/anchor";

/**
 * Donor tier levels based on total contributions
 */
export enum DonorTier {
  Bronze = "bronze",
  Silver = "silver",
  Gold = "gold",
  Platinum = "platinum",
}

/**
 * Vault state account data
 */
export interface VaultState {
  admin: PublicKey;
  totalDonated: BN;
  donationCount: BN;
  isPaused: boolean;
  minDonationAmount: BN;
  maxDonationAmount: BN;
  totalWithdrawn: BN;
  uniqueDonors: BN;
  bump: number;
}

/**
 * Donor information account data
 */
export interface DonorInfo {
  donor: PublicKey;
  totalDonated: BN;
  donationCount: BN;
  lastDonationTimestamp: BN;
  tier: DonorTier;
}

/**
 * Vault statistics (formatted for display)
 */
export interface VaultStatistics {
  admin: PublicKey;
  totalDonated: number;
  totalDonatedSOL: number;
  totalWithdrawn: number;
  totalWithdrawnSOL: number;
  currentBalance: number;
  currentBalanceSOL: number;
  donationCount: number;
  uniqueDonors: number;
  isPaused: boolean;
  minDonationAmount: number;
  minDonationAmountSOL: number;
  maxDonationAmount: number;
  maxDonationAmountSOL: number;
}

/**
 * Donor statistics (formatted for display)
 */
export interface DonorStatistics {
  donor: PublicKey;
  totalDonated: number;
  totalDonatedSOL: number;
  donationCount: number;
  lastDonationTimestamp: Date;
  tier: DonorTier;
  tierName: string;
  tierEmoji: string;
}

/**
 * Donation event data
 */
export interface DonationEvent {
  donor: PublicKey;
  amount: BN;
  amountSOL: number;
  totalDonated: BN;
  donorTier: DonorTier;
  timestamp: number;
}

/**
 * Withdraw event data
 */
export interface WithdrawEvent {
  admin: PublicKey;
  amount: BN;
  amountSOL: number;
  timestamp: number;
}

/**
 * Pause event data
 */
export interface PauseEvent {
  admin: PublicKey;
  paused: boolean;
  timestamp: number;
}

/**
 * Donation limits updated event data
 */
export interface DonationLimitsUpdatedEvent {
  admin: PublicKey;
  oldMinAmount: BN;
  oldMaxAmount: BN;
  newMinAmount: BN;
  newMaxAmount: BN;
  timestamp: number;
}

/**
 * Emergency withdraw event data
 */
export interface EmergencyWithdrawEvent {
  admin: PublicKey;
  amount: BN;
  amountSOL: number;
  reason: string;
  timestamp: number;
}

/**
 * Transaction result
 */
export interface TransactionResult {
  signature: string;
  success: boolean;
  error?: string;
}

/**
 * Donation transaction result
 */
export interface DonationResult extends TransactionResult {
  donor: PublicKey;
  amount: number;
  amountSOL: number;
  newTier?: DonorTier;
  totalDonated: number;
}

/**
 * Withdrawal transaction result
 */
export interface WithdrawalResult extends TransactionResult {
  admin: PublicKey;
  amount: number;
  amountSOL: number;
  remainingBalance: number;
}

/**
 * PDA (Program Derived Address) seeds
 */
export interface PDASeeds {
  vaultState: Buffer[];
  vault: Buffer[];
  donorInfo: (donor: PublicKey) => Buffer[];
}

/**
 * Account addresses
 */
export interface DonationAccounts {
  vaultState: PublicKey;
  vault: PublicKey;
  admin: PublicKey;
  programId: PublicKey;
}

/**
 * Donor account addresses
 */
export interface DonorAccounts extends DonationAccounts {
  donor: PublicKey;
  donorInfo: PublicKey;
}

/**
 * Donation parameters
 */
export interface DonateParams {
  amount: number; // in lamports
  donor: PublicKey;
}

/**
 * Withdrawal parameters
 */
export interface WithdrawParams {
  amount?: number; // in lamports, undefined for full withdrawal
  admin: PublicKey;
}

/**
 * Update admin parameters
 */
export interface UpdateAdminParams {
  newAdmin: PublicKey;
  currentAdmin: PublicKey;
}

/**
 * Update limits parameters
 */
export interface UpdateLimitsParams {
  minAmount: number; // in lamports
  maxAmount: number; // in lamports
  admin: PublicKey;
}

/**
 * Event listener callback types
 */
export type DonationEventCallback = (event: DonationEvent) => void;
export type WithdrawEventCallback = (event: WithdrawEvent) => void;
export type PauseEventCallback = (event: PauseEvent) => void;
export type DonationLimitsUpdatedEventCallback = (event: DonationLimitsUpdatedEvent) => void;
export type EmergencyWithdrawEventCallback = (event: EmergencyWithdrawEvent) => void;

/**
 * Event listeners configuration
 */
export interface EventListeners {
  onDonation?: DonationEventCallback;
  onWithdraw?: WithdrawEventCallback;
  onPause?: PauseEventCallback;
  onLimitsUpdated?: DonationLimitsUpdatedEventCallback;
  onEmergencyWithdraw?: EmergencyWithdrawEventCallback;
}

/**
 * Client options
 */
export interface DonationClientOptions {
  programId: PublicKey;
  confirmOptions?: {
    skipPreflight?: boolean;
    commitment?: "processed" | "confirmed" | "finalized";
    maxRetries?: number;
  };
  eventListeners?: EventListeners;
}

/**
 * Error types
 */
export enum DonationErrorCode {
  DonationTooSmall = 6000,
  DonationTooLarge = 6001,
  Unauthorized = 6002,
  InsufficientFunds = 6003,
  Overflow = 6004,
  ContractPaused = 6005,
  InvalidAmount = 6006,
}

/**
 * Custom error class
 */
export class DonationError extends Error {
  code: DonationErrorCode;

  constructor(code: DonationErrorCode, message: string) {
    super(message);
    this.code = code;
    this.name = "DonationError";
  }
}

/**
 * Tier information
 */
export interface TierInfo {
  tier: DonorTier;
  name: string;
  emoji: string;
  threshold: number; // in lamports
  thresholdSOL: number;
  description: string;
}

/**
 * All tier information
 */
export const TIER_INFO: Record<DonorTier, TierInfo> = {
  [DonorTier.Bronze]: {
    tier: DonorTier.Bronze,
    name: "Bronze",
    emoji: "🥉",
    threshold: 1_000_000,
    thresholdSOL: 0.001,
    description: "Entry level supporter",
  },
  [DonorTier.Silver]: {
    tier: DonorTier.Silver,
    name: "Silver",
    emoji: "🥈",
    threshold: 100_000_000,
    thresholdSOL: 0.1,
    description: "Dedicated contributor",
  },
  [DonorTier.Gold]: {
    tier: DonorTier.Gold,
    name: "Gold",
    emoji: "🥇",
    threshold: 1_000_000_000,
    thresholdSOL: 1.0,
    description: "Premium supporter",
  },
  [DonorTier.Platinum]: {
    tier: DonorTier.Platinum,
    name: "Platinum",
    emoji: "💎",
    threshold: 10_000_000_000,
    thresholdSOL: 10.0,
    description: "Elite benefactor",
  },
};

/**
 * Conversion constants
 */
export const LAMPORTS_PER_SOL = 1_000_000_000;

/**
 * Helper type for account fetching
 */
export type AccountData<T> = {
  publicKey: PublicKey;
  account: T;
};
