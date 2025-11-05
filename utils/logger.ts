/**
 * Logger utility for donation contract
 */

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  NONE = 4,
}

export interface LoggerConfig {
  level: LogLevel;
  enableColors: boolean;
  enableTimestamp: boolean;
  prefix?: string;
}

/**
 * ANSI color codes
 */
const COLORS = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
  cyan: "\x1b[36m",
  white: "\x1b[37m",
  gray: "\x1b[90m",
};

/**
 * Logger class
 */
export class Logger {
  private config: LoggerConfig;

  constructor(config?: Partial<LoggerConfig>) {
    this.config = {
      level: config?.level ?? LogLevel.INFO,
      enableColors: config?.enableColors ?? true,
      enableTimestamp: config?.enableTimestamp ?? true,
      prefix: config?.prefix,
    };
  }

  /**
   * Debug log
   */
  debug(message: string, ...args: any[]): void {
    if (this.config.level <= LogLevel.DEBUG) {
      this.log("DEBUG", COLORS.gray, message, ...args);
    }
  }

  /**
   * Info log
   */
  info(message: string, ...args: any[]): void {
    if (this.config.level <= LogLevel.INFO) {
      this.log("INFO", COLORS.blue, message, ...args);
    }
  }

  /**
   * Success log
   */
  success(message: string, ...args: any[]): void {
    if (this.config.level <= LogLevel.INFO) {
      this.log("SUCCESS", COLORS.green, message, ...args);
    }
  }

  /**
   * Warning log
   */
  warn(message: string, ...args: any[]): void {
    if (this.config.level <= LogLevel.WARN) {
      this.log("WARN", COLORS.yellow, message, ...args);
    }
  }

  /**
   * Error log
   */
  error(message: string, error?: any, ...args: any[]): void {
    if (this.config.level <= LogLevel.ERROR) {
      this.log("ERROR", COLORS.red, message, ...args);
      if (error) {
        console.error(error);
      }
    }
  }

  /**
   * Transaction log
   */
  transaction(signature: string, message?: string): void {
    if (this.config.level <= LogLevel.INFO) {
      const msg = message || "Transaction confirmed";
      this.log("TX", COLORS.cyan, `${msg}: ${signature}`);
    }
  }

  /**
   * Donation log
   */
  donation(amount: number, donor: string, tier?: string): void {
    if (this.config.level <= LogLevel.INFO) {
      const tierStr = tier ? ` [${tier.toUpperCase()}]` : "";
      this.log("DONATION", COLORS.green, `${amount.toFixed(4)} SOL from ${donor}${tierStr}`);
    }
  }

  /**
   * Withdrawal log
   */
  withdrawal(amount: number, admin: string): void {
    if (this.config.level <= LogLevel.INFO) {
      this.log("WITHDRAW", COLORS.magenta, `${amount.toFixed(4)} SOL to ${admin}`);
    }
  }

  /**
   * Base log method
   */
  private log(level: string, color: string, message: string, ...args: any[]): void {
    const timestamp = this.config.enableTimestamp
      ? `[${new Date().toISOString()}]`
      : "";

    const prefix = this.config.prefix ? `[${this.config.prefix}]` : "";

    const levelStr = this.config.enableColors
      ? `${color}${level.padEnd(8)}${COLORS.reset}`
      : level.padEnd(8);

    const parts = [timestamp, prefix, levelStr, message].filter(Boolean);
    console.log(parts.join(" "), ...args);
  }

  /**
   * Update log level
   */
  setLevel(level: LogLevel): void {
    this.config.level = level;
  }

  /**
   * Enable/disable colors
   */
  setColors(enabled: boolean): void {
    this.config.enableColors = enabled;
  }

  /**
   * Enable/disable timestamp
   */
  setTimestamp(enabled: boolean): void {
    this.config.enableTimestamp = enabled;
  }

  /**
   * Create a child logger with a prefix
   */
  child(prefix: string): Logger {
    return new Logger({
      ...this.config,
      prefix: this.config.prefix ? `${this.config.prefix}:${prefix}` : prefix,
    });
  }
}

/**
 * Create logger from environment
 */
export function createLogger(prefix?: string): Logger {
  const logLevelStr = process.env.LOG_LEVEL?.toLowerCase() || "info";

  const levelMap: Record<string, LogLevel> = {
    debug: LogLevel.DEBUG,
    info: LogLevel.INFO,
    warn: LogLevel.WARN,
    error: LogLevel.ERROR,
    none: LogLevel.NONE,
  };

  const level = levelMap[logLevelStr] ?? LogLevel.INFO;

  return new Logger({
    level,
    enableColors: process.env.NO_COLOR !== "1",
    enableTimestamp: process.env.LOG_TIMESTAMP !== "false",
    prefix,
  });
}

/**
 * Default logger instance
 */
export const logger = createLogger("DonationContract");

/**
 * Format SOL amount
 */
export function formatSOL(lamports: number): string {
  return `${(lamports / 1e9).toFixed(4)} SOL`;
}

/**
 * Format public key (short)
 */
export function formatPubkey(pubkey: string): string {
  return `${pubkey.slice(0, 4)}...${pubkey.slice(-4)}`;
}

/**
 * Format tier with emoji
 */
export function formatTier(tier: string): string {
  const tiers: Record<string, string> = {
    bronze: "🥉 Bronze",
    silver: "🥈 Silver",
    gold: "🥇 Gold",
    platinum: "💎 Platinum",
  };
  return tiers[tier.toLowerCase()] || tier;
}

/**
 * Progress bar utility
 */
export function createProgressBar(
  current: number,
  total: number,
  width: number = 40
): string {
  const percentage = Math.min(100, (current / total) * 100);
  const filled = Math.floor((percentage / 100) * width);
  const empty = width - filled;

  const bar = "█".repeat(filled) + "░".repeat(empty);
  return `${bar} ${percentage.toFixed(1)}%`;
}

/**
 * Table formatter
 */
export function formatTable(
  headers: string[],
  rows: string[][]
): string {
  const colWidths = headers.map((header, i) => {
    const cellWidths = rows.map(row => (row[i] || "").length);
    return Math.max(header.length, ...cellWidths);
  });

  const formatRow = (cells: string[]) => {
    return cells
      .map((cell, i) => cell.padEnd(colWidths[i]))
      .join(" | ");
  };

  const separator = colWidths.map(w => "-".repeat(w)).join("-+-");

  return [
    formatRow(headers),
    separator,
    ...rows.map(formatRow),
  ].join("\n");
}
