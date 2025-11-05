/**
 * Validation utilities for donation contract
 */

import { PublicKey } from "@solana/web3.js";
import { ValidationError } from "./errors";

/**
 * Validation result
 */
export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

/**
 * Validate public key
 */
export function isValidPublicKey(value: string): boolean {
  try {
    new PublicKey(value);
    return true;
  } catch {
    return false;
  }
}

/**
 * Validate donation amount
 */
export function validateDonationAmount(
  amount: number,
  minAmount: number = 1_000_000,
  maxAmount: number = 100_000_000_000
): ValidationResult {
  const errors: string[] = [];

  if (amount <= 0) {
    errors.push("Amount must be greater than 0");
  }

  if (amount < minAmount) {
    errors.push(`Amount must be at least ${minAmount / 1e9} SOL`);
  }

  if (amount > maxAmount) {
    errors.push(`Amount cannot exceed ${maxAmount / 1e9} SOL`);
  }

  if (!Number.isInteger(amount)) {
    errors.push("Amount must be an integer (lamports)");
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validate withdrawal amount
 */
export function validateWithdrawalAmount(
  amount: number,
  vaultBalance: number,
  rentExemptMinimum: number = 890880
): ValidationResult {
  const errors: string[] = [];

  if (amount <= 0) {
    errors.push("Withdrawal amount must be greater than 0");
  }

  if (!Number.isInteger(amount)) {
    errors.push("Amount must be an integer (lamports)");
  }

  const availableBalance = vaultBalance - rentExemptMinimum;

  if (amount > availableBalance) {
    errors.push(
      `Insufficient funds. Available: ${availableBalance / 1e9} SOL, Requested: ${amount / 1e9} SOL`
    );
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validate donation limits
 */
export function validateDonationLimits(
  minAmount: number,
  maxAmount: number
): ValidationResult {
  const errors: string[] = [];

  if (minAmount <= 0) {
    errors.push("Minimum amount must be greater than 0");
  }

  if (maxAmount <= 0) {
    errors.push("Maximum amount must be greater than 0");
  }

  if (minAmount >= maxAmount) {
    errors.push("Minimum amount must be less than maximum amount");
  }

  if (!Number.isInteger(minAmount) || !Number.isInteger(maxAmount)) {
    errors.push("Amounts must be integers (lamports)");
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validate public key string
 */
export function validatePublicKey(pubkey: string, fieldName: string = "Public key"): void {
  if (!pubkey) {
    throw new ValidationError(`${fieldName} is required`, fieldName);
  }

  if (!isValidPublicKey(pubkey)) {
    throw new ValidationError(`${fieldName} is not a valid Solana public key`, fieldName);
  }
}

/**
 * Validate admin authorization
 */
export function validateAdminAuthorization(
  signer: PublicKey,
  admin: PublicKey
): void {
  if (!signer.equals(admin)) {
    throw new ValidationError(
      "Signer is not authorized. Only admin can perform this action.",
      "admin"
    );
  }
}

/**
 * Validate contract not paused
 */
export function validateContractNotPaused(isPaused: boolean): void {
  if (isPaused) {
    throw new ValidationError(
      "Contract is paused. Donations are currently disabled.",
      "isPaused"
    );
  }
}

/**
 * Validate SOL amount (float)
 */
export function validateSOLAmount(amountSOL: number): ValidationResult {
  const errors: string[] = [];

  if (amountSOL <= 0) {
    errors.push("SOL amount must be greater than 0");
  }

  if (!Number.isFinite(amountSOL)) {
    errors.push("SOL amount must be a finite number");
  }

  if (amountSOL < 0.000000001) {
    errors.push("SOL amount is too small (minimum: 0.000000001 SOL)");
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validate network
 */
export function validateNetwork(
  network: string
): network is "devnet" | "testnet" | "mainnet-beta" | "localnet" {
  const validNetworks = ["devnet", "testnet", "mainnet-beta", "localnet"];
  return validNetworks.includes(network);
}

/**
 * Validate RPC URL
 */
export function validateRPCUrl(url: string): ValidationResult {
  const errors: string[] = [];

  if (!url) {
    errors.push("RPC URL is required");
  }

  try {
    const parsedUrl = new URL(url);
    if (!["http:", "https:"].includes(parsedUrl.protocol)) {
      errors.push("RPC URL must use http or https protocol");
    }
  } catch {
    errors.push("Invalid RPC URL format");
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Validate keypair path
 */
export function validateKeypairPath(path: string): ValidationResult {
  const errors: string[] = [];

  if (!path) {
    errors.push("Keypair path is required");
  }

  if (!path.endsWith(".json")) {
    errors.push("Keypair file must have .json extension");
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Sanitize amount input
 */
export function sanitizeAmount(value: any): number {
  if (typeof value === "number") {
    return Math.floor(value);
  }

  if (typeof value === "string") {
    const parsed = parseFloat(value);
    if (Number.isNaN(parsed)) {
      throw new ValidationError("Invalid number format", "amount");
    }
    return Math.floor(parsed);
  }

  throw new ValidationError("Amount must be a number or string", "amount");
}

/**
 * Convert SOL to lamports with validation
 */
export function solToLamports(sol: number): number {
  const validation = validateSOLAmount(sol);
  if (!validation.valid) {
    throw new ValidationError(validation.errors[0], "sol");
  }

  return Math.floor(sol * 1e9);
}

/**
 * Convert lamports to SOL with validation
 */
export function lamportsToSOL(lamports: number): number {
  if (lamports < 0) {
    throw new ValidationError("Lamports cannot be negative", "lamports");
  }

  if (!Number.isInteger(lamports)) {
    throw new ValidationError("Lamports must be an integer", "lamports");
  }

  return lamports / 1e9;
}

/**
 * Validate tier
 */
export function validateTier(tier: string): boolean {
  const validTiers = ["bronze", "silver", "gold", "platinum"];
  return validTiers.includes(tier.toLowerCase());
}

/**
 * Batch validation
 */
export function validateAll(
  validations: Array<() => ValidationResult>
): ValidationResult {
  const allErrors: string[] = [];

  for (const validation of validations) {
    const result = validation();
    if (!result.valid) {
      allErrors.push(...result.errors);
    }
  }

  return {
    valid: allErrors.length === 0,
    errors: allErrors,
  };
}

/**
 * Assert validation result
 */
export function assertValid(result: ValidationResult): void {
  if (!result.valid) {
    throw new ValidationError(result.errors.join(", "));
  }
}
