// Zig Solana Donation Client
//
// A high-performance, memory-safe client for interacting with the
// Solana donation smart contract. Features explicit memory management
// and compile-time safety guarantees.
//
// Example:
//   var client = try DonationClient.init(allocator, .{});
//   defer client.deinit();
//   const result = try client.donate(donor, 0.5);

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// =============================================================================
// Constants
// =============================================================================

pub const LAMPORTS_PER_SOL: u64 = 1_000_000_000;
pub const MIN_DONATION: u64 = 1_000_000; // 0.001 SOL
pub const MAX_DONATION: u64 = 100_000_000_000; // 100 SOL

pub const TIER_BRONZE: u64 = 1_000_000;
pub const TIER_SILVER: u64 = 100_000_000;
pub const TIER_GOLD: u64 = 1_000_000_000;
pub const TIER_PLATINUM: u64 = 10_000_000_000;

// =============================================================================
// Types
// =============================================================================

/// Donor tier classification based on total donations
pub const DonorTier = enum {
    bronze, // >= 0.001 SOL
    silver, // >= 0.1 SOL
    gold, // >= 1 SOL
    platinum, // >= 10 SOL

    /// Calculate tier from lamports amount
    pub fn fromLamports(lamports: u64) DonorTier {
        if (lamports >= TIER_PLATINUM) return .platinum;
        if (lamports >= TIER_GOLD) return .gold;
        if (lamports >= TIER_SILVER) return .silver;
        return .bronze;
    }

    /// Get emoji representation of tier
    pub fn emoji(self: DonorTier) []const u8 {
        return switch (self) {
            .bronze => "🥉",
            .silver => "🥈",
            .gold => "🥇",
            .platinum => "💎",
        };
    }

    /// Get name of tier
    pub fn name(self: DonorTier) []const u8 {
        return switch (self) {
            .bronze => "Bronze",
            .silver => "Silver",
            .gold => "Gold",
            .platinum => "Platinum",
        };
    }

    /// Get next tier and its threshold
    pub fn nextTier(self: DonorTier) ?struct { tier: DonorTier, threshold: u64 } {
        return switch (self) {
            .bronze => .{ .tier = .silver, .threshold = TIER_SILVER },
            .silver => .{ .tier = .gold, .threshold = TIER_GOLD },
            .gold => .{ .tier = .platinum, .threshold = TIER_PLATINUM },
            .platinum => null,
        };
    }
};

/// Amount in lamports with conversion utilities
pub const Lamports = struct {
    value: u64,

    /// Create from SOL amount
    pub fn fromSol(sol: f64) Lamports {
        return .{ .value = @intFromFloat(sol * @as(f64, @floatFromInt(LAMPORTS_PER_SOL))) };
    }

    /// Convert to SOL
    pub fn toSol(self: Lamports) f64 {
        return @as(f64, @floatFromInt(self.value)) / @as(f64, @floatFromInt(LAMPORTS_PER_SOL));
    }

    /// Format for printing
    pub fn format(
        self: Lamports,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d} lamports ({d:.9} SOL)", .{ self.value, self.toSol() });
    }
};

/// Result of a donation operation
pub const DonationResult = struct {
    signature: []const u8,
    amount: Lamports,
    donor: []const u8,
    new_tier: DonorTier,
    total_donated: Lamports,

    pub fn deinit(self: *DonationResult, allocator: Allocator) void {
        allocator.free(self.signature);
        allocator.free(self.donor);
    }
};

/// Vault statistics
pub const VaultStats = struct {
    admin: []const u8,
    total_donated: Lamports,
    total_withdrawn: Lamports,
    current_balance: Lamports,
    donation_count: u64,
    unique_donors: u64,
    is_paused: bool,
    min_donation_amount: Lamports,
    max_donation_amount: Lamports,

    pub fn deinit(self: *VaultStats, allocator: Allocator) void {
        allocator.free(self.admin);
    }
};

/// Donor information
pub const DonorInfo = struct {
    donor: []const u8,
    total_donated: Lamports,
    donation_count: u64,
    last_donation_timestamp: i64,
    tier: DonorTier,

    /// Calculate lamports needed to reach next tier
    pub fn lamportsToNextTier(self: DonorInfo) ?Lamports {
        const next = self.tier.nextTier() orelse return null;
        const threshold = Lamports{ .value = next.threshold };

        if (self.total_donated.value >= threshold.value) return null;

        return Lamports{ .value = threshold.value - self.total_donated.value };
    }

    pub fn deinit(self: *DonorInfo, allocator: Allocator) void {
        allocator.free(self.donor);
    }
};

// =============================================================================
// Errors
// =============================================================================

pub const DonationError = error{
    DonationTooSmall,
    DonationTooLarge,
    ContractPaused,
    InsufficientFunds,
    Unauthorized,
    NetworkError,
    ParseError,
    OutOfMemory,
};

// =============================================================================
// Client Configuration
// =============================================================================

pub const ClientConfig = struct {
    rpc_url: []const u8 = "https://api.devnet.solana.com",
    program_id: []const u8 = "DoNaT1on111111111111111111111111111111111111",
};

// =============================================================================
// Main Client
// =============================================================================

pub const DonationClient = struct {
    allocator: Allocator,
    rpc_url: []const u8,
    program_id: []const u8,

    /// Initialize a new donation client
    ///
    /// Example:
    ///   var client = try DonationClient.init(allocator, .{});
    ///   defer client.deinit();
    pub fn init(allocator: Allocator, config: ClientConfig) !DonationClient {
        return DonationClient{
            .allocator = allocator,
            .rpc_url = config.rpc_url,
            .program_id = config.program_id,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *DonationClient) void {
        _ = self;
        // Cleanup if needed
    }

    /// Make a donation to the vault
    ///
    /// Args:
    ///   donor: Donor's public key
    ///   amount_sol: Amount in SOL
    ///
    /// Returns:
    ///   DonationResult with signature and updated info
    ///
    /// Example:
    ///   const result = try client.donate(donor, 0.5);
    ///   defer result.deinit(allocator);
    pub fn donate(
        self: *DonationClient,
        donor: []const u8,
        amount_sol: f64,
    ) !DonationResult {
        const amount = Lamports.fromSol(amount_sol);

        // Validate donation amount
        try self.validateDonation(amount);

        // Check if contract is paused
        var stats = try self.getVaultStats();
        defer stats.deinit(self.allocator);

        if (stats.is_paused) return error.ContractPaused;

        // Send transaction (placeholder)
        const signature = try std.fmt.allocPrint(
            self.allocator,
            "signature_{d}",
            .{std.crypto.random.int(u64)},
        );

        // Get updated donor info
        var donor_info = try self.getDonorInfo(donor);
        defer donor_info.deinit(self.allocator);

        const donor_copy = try self.allocator.dupe(u8, donor);

        return DonationResult{
            .signature = signature,
            .amount = amount,
            .donor = donor_copy,
            .new_tier = donor_info.tier,
            .total_donated = donor_info.total_donated,
        };
    }

    /// Get vault statistics
    ///
    /// Returns:
    ///   VaultStats with current vault information
    ///
    /// Example:
    ///   const stats = try client.getVaultStats();
    ///   defer stats.deinit(allocator);
    pub fn getVaultStats(self: *DonationClient) !VaultStats {
        // Placeholder implementation - would call RPC endpoint
        const admin = try self.allocator.dupe(u8, "Admin123...");

        return VaultStats{
            .admin = admin,
            .total_donated = .{ .value = 1_000_000_000 },
            .total_withdrawn = .{ .value = 0 },
            .current_balance = .{ .value = 1_000_000_000 },
            .donation_count = 10,
            .unique_donors = 5,
            .is_paused = false,
            .min_donation_amount = .{ .value = MIN_DONATION },
            .max_donation_amount = .{ .value = MAX_DONATION },
        };
    }

    /// Get donor information
    ///
    /// Args:
    ///   donor: Donor's public key
    ///
    /// Returns:
    ///   DonorInfo with donor statistics and tier
    ///
    /// Example:
    ///   const info = try client.getDonorInfo(donor);
    ///   defer info.deinit(allocator);
    pub fn getDonorInfo(self: *DonationClient, donor: []const u8) !DonorInfo {
        // Placeholder implementation - would call RPC endpoint
        const donor_copy = try self.allocator.dupe(u8, donor);
        const total_donated = Lamports{ .value = 500_000_000 };

        return DonorInfo{
            .donor = donor_copy,
            .total_donated = total_donated,
            .donation_count = 3,
            .last_donation_timestamp = std.time.timestamp(),
            .tier = DonorTier.fromLamports(total_donated.value),
        };
    }

    /// Withdraw funds from the vault (admin only)
    ///
    /// Args:
    ///   admin: Admin's public key
    ///   amount_sol: Amount to withdraw in SOL
    ///
    /// Returns:
    ///   Transaction signature
    ///
    /// Example:
    ///   const sig = try client.withdraw(admin, 1.0);
    ///   defer allocator.free(sig);
    pub fn withdraw(
        self: *DonationClient,
        admin: []const u8,
        amount_sol: f64,
    ) ![]const u8 {
        const amount = Lamports.fromSol(amount_sol);

        // Get vault stats
        var stats = try self.getVaultStats();
        defer stats.deinit(self.allocator);

        // Check authorization
        if (!std.mem.eql(u8, admin, stats.admin)) {
            return error.Unauthorized;
        }

        // Check sufficient funds
        if (amount.value > stats.current_balance.value) {
            return error.InsufficientFunds;
        }

        // Send transaction (placeholder)
        return try std.fmt.allocPrint(
            self.allocator,
            "withdraw_signature_{d}",
            .{std.crypto.random.int(u64)},
        );
    }

    // =========================================================================
    // Private Methods
    // =========================================================================

    fn validateDonation(self: *DonationClient, amount: Lamports) !void {
        _ = self;
        if (amount.value < MIN_DONATION) return error.DonationTooSmall;
        if (amount.value > MAX_DONATION) return error.DonationTooLarge;
    }
};

// =============================================================================
// Utility Functions
// =============================================================================

/// Convert SOL to lamports
pub fn sol(amount: f64) Lamports {
    return Lamports.fromSol(amount);
}

/// Calculate donation percentage
pub fn donationPercentage(donor_amount: Lamports, total_amount: Lamports) f64 {
    if (total_amount.value == 0) return 0.0;
    return (@as(f64, @floatFromInt(donor_amount.value)) / @as(f64, @floatFromInt(total_amount.value))) * 100.0;
}

/// Format time ago
pub fn formatTimeAgo(allocator: Allocator, timestamp: i64) ![]const u8 {
    const now = std.time.timestamp();
    const diff = now - timestamp;

    const days = @divTrunc(diff, 86400);
    const hours = @divTrunc(@mod(diff, 86400), 3600);
    const minutes = @divTrunc(@mod(diff, 3600), 60);

    if (days > 0) {
        return try std.fmt.allocPrint(allocator, "{d} days ago", .{days});
    } else if (hours > 0) {
        return try std.fmt.allocPrint(allocator, "{d} hours ago", .{hours});
    } else if (minutes > 0) {
        return try std.fmt.allocPrint(allocator, "{d} minutes ago", .{minutes});
    } else {
        return try allocator.dupe(u8, "just now");
    }
}

// =============================================================================
// Example Usage
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Zig Solana Donation Client ===\n\n", .{});

    // Create client
    var client = try DonationClient.init(allocator, .{});
    defer client.deinit();
    std.debug.print("✓ Client created\n", .{});

    // Example donor
    const donor = "DonorPubkey123...";

    // Make donation
    std.debug.print("\n✓ Making donation...\n", .{});
    var result = try client.donate(donor, 0.5);
    defer result.deinit(allocator);

    std.debug.print("  Signature: {s}\n", .{result.signature});
    std.debug.print("  Amount: {}\n", .{result.amount});
    std.debug.print("  Tier: {s} {s}\n", .{ result.new_tier.name(), result.new_tier.emoji() });

    // Get vault stats
    std.debug.print("\n✓ Vault statistics:\n", .{});
    var stats = try client.getVaultStats();
    defer stats.deinit(allocator);

    std.debug.print("  Total donated: {}\n", .{stats.total_donated});
    std.debug.print("  Current balance: {}\n", .{stats.current_balance});
    std.debug.print("  Donations: {d}\n", .{stats.donation_count});
    std.debug.print("  Unique donors: {d}\n", .{stats.unique_donors});

    // Get donor info
    std.debug.print("\n✓ Donor information:\n", .{});
    var info = try client.getDonorInfo(donor);
    defer info.deinit(allocator);

    std.debug.print("  Total: {}\n", .{info.total_donated});
    std.debug.print("  Count: {d}\n", .{info.donation_count});
    std.debug.print("  Tier: {s} {s}\n", .{ info.tier.name(), info.tier.emoji() });

    // Check next tier
    if (info.lamportsToNextTier()) |needed| {
        std.debug.print("  Need {d:.4} SOL for next tier\n", .{needed.toSol()});
    } else {
        std.debug.print("  Max tier reached! 💎\n", .{});
    }
}
