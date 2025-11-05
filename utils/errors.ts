/**
 * Error handling utilities for donation contract
 */

import { AnchorError } from "@coral-xyz/anchor";

/**
 * Custom error codes from the contract
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
 * Error messages mapping
 */
export const ERROR_MESSAGES: Record<DonationErrorCode, string> = {
  [DonationErrorCode.DonationTooSmall]: "Donation amount is too small. Minimum is 0.001 SOL.",
  [DonationErrorCode.DonationTooLarge]: "Donation amount is too large. Maximum is 100 SOL.",
  [DonationErrorCode.Unauthorized]: "Only the admin can perform this action.",
  [DonationErrorCode.InsufficientFunds]: "Insufficient funds in the vault.",
  [DonationErrorCode.Overflow]: "Arithmetic overflow occurred.",
  [DonationErrorCode.ContractPaused]: "The contract is currently paused. Donations are disabled.",
  [DonationErrorCode.InvalidAmount]: "Invalid amount specified. Amount must be greater than 0.",
};

/**
 * Custom donation error class
 */
export class DonationError extends Error {
  code: DonationErrorCode;
  originalError?: Error;

  constructor(code: DonationErrorCode, originalError?: Error) {
    super(ERROR_MESSAGES[code] || "Unknown error");
    this.name = "DonationError";
    this.code = code;
    this.originalError = originalError;
  }

  /**
   * Get user-friendly error message
   */
  getUserMessage(): string {
    return ERROR_MESSAGES[this.code] || this.message;
  }

  /**
   * Get error code as string
   */
  getCodeString(): string {
    return DonationErrorCode[this.code];
  }
}

/**
 * Network error
 */
export class NetworkError extends Error {
  constructor(message: string, public originalError?: Error) {
    super(message);
    this.name = "NetworkError";
  }
}

/**
 * Configuration error
 */
export class ConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConfigurationError";
  }
}

/**
 * Validation error
 */
export class ValidationError extends Error {
  constructor(message: string, public field?: string) {
    super(message);
    this.name = "ValidationError";
  }
}

/**
 * Parse Anchor error to DonationError
 */
export function parseAnchorError(error: any): Error {
  if (error instanceof AnchorError) {
    const errorCode = error.error?.errorCode?.code;

    // Map error code to DonationErrorCode
    const codeMapping: Record<string, DonationErrorCode> = {
      DonationTooSmall: DonationErrorCode.DonationTooSmall,
      DonationTooLarge: DonationErrorCode.DonationTooLarge,
      Unauthorized: DonationErrorCode.Unauthorized,
      InsufficientFunds: DonationErrorCode.InsufficientFunds,
      Overflow: DonationErrorCode.Overflow,
      ContractPaused: DonationErrorCode.ContractPaused,
      InvalidAmount: DonationErrorCode.InvalidAmount,
    };

    if (errorCode && errorCode in codeMapping) {
      return new DonationError(codeMapping[errorCode], error);
    }
  }

  return error;
}

/**
 * Handle error with retry logic
 */
export async function withRetry<T>(
  fn: () => Promise<T>,
  options: {
    maxRetries?: number;
    delayMs?: number;
    onRetry?: (attempt: number, error: Error) => void;
  } = {}
): Promise<T> {
  const { maxRetries = 3, delayMs = 1000, onRetry } = options;

  let lastError: Error;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      if (attempt < maxRetries) {
        onRetry?.(attempt + 1, lastError);
        await sleep(delayMs * Math.pow(2, attempt)); // Exponential backoff
      }
    }
  }

  throw lastError!;
}

/**
 * Sleep utility
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Handle error with fallback
 */
export async function withFallback<T>(
  fn: () => Promise<T>,
  fallback: T | (() => T)
): Promise<T> {
  try {
    return await fn();
  } catch (error) {
    return typeof fallback === "function" ? (fallback as () => T)() : fallback;
  }
}

/**
 * Assert condition
 */
export function assert(condition: boolean, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

/**
 * Assert is defined
 */
export function assertDefined<T>(
  value: T | undefined | null,
  message: string = "Value is undefined"
): asserts value is T {
  if (value === undefined || value === null) {
    throw new Error(message);
  }
}

/**
 * Try-catch wrapper that returns result or error
 */
export async function tryAsync<T, E = Error>(
  fn: () => Promise<T>
): Promise<[T, null] | [null, E]> {
  try {
    const result = await fn();
    return [result, null];
  } catch (error) {
    return [null, error as E];
  }
}

/**
 * Synchronous try-catch wrapper
 */
export function trySync<T, E = Error>(fn: () => T): [T, null] | [null, E] {
  try {
    const result = fn();
    return [result, null];
  } catch (error) {
    return [null, error as E];
  }
}

/**
 * Error reporter interface
 */
export interface ErrorReporter {
  report(error: Error, context?: Record<string, any>): void;
}

/**
 * Console error reporter
 */
export class ConsoleErrorReporter implements ErrorReporter {
  report(error: Error, context?: Record<string, any>): void {
    console.error("Error:", error);
    if (context) {
      console.error("Context:", context);
    }
  }
}

/**
 * Create error handler
 */
export function createErrorHandler(reporter?: ErrorReporter) {
  const errorReporter = reporter || new ConsoleErrorReporter();

  return {
    handle(error: Error, context?: Record<string, any>): void {
      const parsedError = parseAnchorError(error);
      errorReporter.report(parsedError, context);
    },

    async handleAsync<T>(
      fn: () => Promise<T>,
      context?: Record<string, any>
    ): Promise<T | null> {
      try {
        return await fn();
      } catch (error) {
        this.handle(error as Error, context);
        return null;
      }
    },
  };
}

/**
 * Format error for display
 */
export function formatError(error: Error): string {
  if (error instanceof DonationError) {
    return `[${error.getCodeString()}] ${error.getUserMessage()}`;
  }

  if (error instanceof ValidationError) {
    return `Validation Error${error.field ? ` (${error.field})` : ""}: ${error.message}`;
  }

  if (error instanceof NetworkError) {
    return `Network Error: ${error.message}`;
  }

  if (error instanceof ConfigurationError) {
    return `Configuration Error: ${error.message}`;
  }

  return error.message || "Unknown error occurred";
}

/**
 * Check if error is retryable
 */
export function isRetryableError(error: Error): boolean {
  if (error instanceof NetworkError) {
    return true;
  }

  // Network-related errors are typically retryable
  const retryableMessages = [
    "timeout",
    "network",
    "connection",
    "ECONNREFUSED",
    "ETIMEDOUT",
    "ENOTFOUND",
  ];

  return retryableMessages.some((msg) =>
    error.message.toLowerCase().includes(msg)
  );
}

/**
 * Default error handler instance
 */
export const errorHandler = createErrorHandler();
