# Crystal Solana Donation Client
#
# A fast, type-safe client for interacting with the Solana donation
# smart contract. Combines Ruby-like elegance with C-like performance.
#
# Example:
#   client = DonationClient.new
#   result = client.donate(donor_pubkey, amount: 0.5)
#   puts "Signature: #{result.signature}"

require "json"
require "http/client"
require "big"

# =============================================================================
# Constants
# =============================================================================

LAMPORTS_PER_SOL = 1_000_000_000_u64
MIN_DONATION     = 1_000_000_u64  # 0.001 SOL
MAX_DONATION     = 100_000_000_000_u64  # 100 SOL

TIER_BRONZE   = 1_000_000_u64
TIER_SILVER   = 100_000_000_u64
TIER_GOLD     = 1_000_000_000_u64
TIER_PLATINUM = 10_000_000_000_u64

# =============================================================================
# Types and Structures
# =============================================================================

# Donor tier classification
enum DonorTier
  Bronze   # >= 0.001 SOL
  Silver   # >= 0.1 SOL
  Gold     # >= 1 SOL
  Platinum # >= 10 SOL

  # Get emoji representation
  def emoji : String
    case self
    when Bronze   then "🥉"
    when Silver   then "🥈"
    when Gold     then "🥇"
    when Platinum then "💎"
    end
  end

  # Get tier name
  def to_s : String
    case self
    when Bronze   then "Bronze"
    when Silver   then "Silver"
    when Gold     then "Gold"
    when Platinum then "Platinum"
    end
  end

  # Calculate tier from total donated amount
  def self.from_lamports(lamports : UInt64) : DonorTier
    if lamports >= TIER_PLATINUM
      Platinum
    elsif lamports >= TIER_GOLD
      Gold
    elsif lamports >= TIER_SILVER
      Silver
    else
      Bronze
    end
  end

  # Get next tier and threshold
  def next_tier : Tuple(DonorTier, UInt64)?
    case self
    when Bronze   then {Silver, TIER_SILVER}
    when Silver   then {Gold, TIER_GOLD}
    when Gold     then {Platinum, TIER_PLATINUM}
    when Platinum then nil
    end
  end
end

# Amount in lamports
struct Lamports
  getter value : UInt64

  def initialize(@value : UInt64)
  end

  def self.from_sol(sol : Float64) : Lamports
    new((sol * LAMPORTS_PER_SOL).to_u64)
  end

  def to_sol : Float64
    value.to_f64 / LAMPORTS_PER_SOL
  end

  def +(other : Lamports) : Lamports
    Lamports.new(value + other.value)
  end

  def -(other : Lamports) : Lamports
    Lamports.new(value - other.value)
  end

  def >(other : Lamports) : Bool
    value > other.value
  end

  def <(other : Lamports) : Bool
    value < other.value
  end

  def >=(other : Lamports) : Bool
    value >= other.value
  end

  def <=(other : Lamports) : Bool
    value <= other.value
  end

  def to_s(io : IO)
    io << value << " lamports (" << to_sol.round(9) << " SOL)"
  end
end

# Donation result
struct DonationResult
  getter signature : String
  getter amount : Lamports
  getter donor : String
  getter new_tier : DonorTier
  getter total_donated : Lamports

  def initialize(
    @signature : String,
    @amount : Lamports,
    @donor : String,
    @new_tier : DonorTier,
    @total_donated : Lamports
  )
  end

  def to_s(io : IO)
    io << "DonationResult(\n"
    io << "  signature: " << signature << "\n"
    io << "  amount: " << amount << "\n"
    io << "  donor: " << donor << "\n"
    io << "  tier: " << new_tier.emoji << " " << new_tier << "\n"
    io << "  total: " << total_donated << "\n"
    io << ")"
  end
end

# Vault statistics
struct VaultStats
  getter admin : String
  getter total_donated : Lamports
  getter total_withdrawn : Lamports
  getter current_balance : Lamports
  getter donation_count : UInt64
  getter unique_donors : UInt64
  getter is_paused : Bool
  getter min_donation_amount : Lamports
  getter max_donation_amount : Lamports

  def initialize(
    @admin : String,
    @total_donated : Lamports,
    @total_withdrawn : Lamports,
    @current_balance : Lamports,
    @donation_count : UInt64,
    @unique_donors : UInt64,
    @is_paused : Bool,
    @min_donation_amount : Lamports,
    @max_donation_amount : Lamports
  )
  end

  def to_s(io : IO)
    io << "VaultStats(\n"
    io << "  admin: " << admin << "\n"
    io << "  total_donated: " << total_donated << "\n"
    io << "  total_withdrawn: " << total_withdrawn << "\n"
    io << "  current_balance: " << current_balance << "\n"
    io << "  donations: " << donation_count << "\n"
    io << "  unique_donors: " << unique_donors << "\n"
    io << "  paused: " << is_paused << "\n"
    io << ")"
  end
end

# Donor information
struct DonorInfo
  getter donor : String
  getter total_donated : Lamports
  getter donation_count : UInt64
  getter last_donation_timestamp : Int64
  getter tier : DonorTier

  def initialize(
    @donor : String,
    @total_donated : Lamports,
    @donation_count : UInt64,
    @last_donation_timestamp : Int64,
    @tier : DonorTier
  )
  end

  # Calculate lamports to next tier
  def lamports_to_next_tier : Lamports?
    next_tier_info = tier.next_tier
    return nil unless next_tier_info

    _, threshold = next_tier_info
    threshold_lamports = Lamports.new(threshold)

    if total_donated >= threshold_lamports
      nil
    else
      threshold_lamports - total_donated
    end
  end

  def to_s(io : IO)
    io << "DonorInfo(\n"
    io << "  donor: " << donor << "\n"
    io << "  total: " << total_donated << "\n"
    io << "  count: " << donation_count << "\n"
    io << "  tier: " << tier.emoji << " " << tier << "\n"

    if needed = lamports_to_next_tier
      io << "  to_next_tier: " << needed << "\n"
    else
      io << "  status: Max tier reached! 💎\n"
    end

    io << ")"
  end
end

# =============================================================================
# Custom Exceptions
# =============================================================================

class DonationError < Exception
end

class DonationTooSmallError < DonationError
  def initialize(actual : Lamports, minimum : Lamports)
    super("Donation of #{actual} is below minimum of #{minimum}")
  end
end

class DonationTooLargeError < DonationError
  def initialize(actual : Lamports, maximum : Lamports)
    super("Donation of #{actual} exceeds maximum of #{maximum}")
  end
end

class ContractPausedError < DonationError
  def initialize
    super("Contract is currently paused")
  end
end

class InsufficientFundsError < DonationError
  def initialize(required : Lamports, available : Lamports)
    super("Insufficient funds: need #{required}, have #{available}")
  end
end

class UnauthorizedError < DonationError
  def initialize(caller : String, expected : String)
    super("Unauthorized: expected #{expected}, got #{caller}")
  end
end

# =============================================================================
# Client Implementation
# =============================================================================

class DonationClient
  @rpc_url : String
  @program_id : String

  def initialize(
    @rpc_url : String = "https://api.devnet.solana.com",
    @program_id : String = "DoNaT1on111111111111111111111111111111111111"
  )
  end

  # Make a donation to the vault
  #
  # Example:
  #   result = client.donate(donor_pubkey, amount: 0.5)
  #   puts "Signature: #{result.signature}"
  def donate(donor : String, amount : Float64) : DonationResult
    lamports = Lamports.from_sol(amount)

    # Validate donation amount
    validate_donation(lamports)

    # Check if contract is paused
    stats = vault_stats
    raise ContractPausedError.new if stats.is_paused

    # Send transaction (placeholder)
    signature = "signature_#{Random::Secure.hex(16)}"

    # Get updated donor info
    donor_info = donor_info(donor)

    DonationResult.new(
      signature: signature,
      amount: lamports,
      donor: donor,
      new_tier: donor_info.tier,
      total_donated: donor_info.total_donated
    )
  end

  # Get vault statistics
  #
  # Example:
  #   stats = client.vault_stats
  #   puts "Total: #{stats.total_donated.to_sol} SOL"
  def vault_stats : VaultStats
    # Placeholder implementation - would call RPC endpoint
    VaultStats.new(
      admin: "Admin123...",
      total_donated: Lamports.new(1_000_000_000_u64),
      total_withdrawn: Lamports.new(0_u64),
      current_balance: Lamports.new(1_000_000_000_u64),
      donation_count: 10_u64,
      unique_donors: 5_u64,
      is_paused: false,
      min_donation_amount: Lamports.new(MIN_DONATION),
      max_donation_amount: Lamports.new(MAX_DONATION)
    )
  end

  # Get donor information
  #
  # Example:
  #   info = client.donor_info(donor_pubkey)
  #   puts "Tier: #{info.tier.emoji}"
  def donor_info(donor : String) : DonorInfo
    # Placeholder implementation - would call RPC endpoint
    total_donated = Lamports.new(500_000_000_u64)

    DonorInfo.new(
      donor: donor,
      total_donated: total_donated,
      donation_count: 3_u64,
      last_donation_timestamp: Time.utc.to_unix,
      tier: DonorTier.from_lamports(total_donated.value)
    )
  end

  # Withdraw funds from the vault (admin only)
  #
  # Example:
  #   signature = client.withdraw(admin_pubkey, amount: 1.0)
  def withdraw(admin : String, amount : Float64) : String
    lamports = Lamports.from_sol(amount)

    # Get vault stats
    stats = vault_stats

    # Check authorization
    unless admin == stats.admin
      raise UnauthorizedError.new(admin, stats.admin)
    end

    # Check sufficient funds
    unless stats.current_balance >= lamports
      raise InsufficientFundsError.new(lamports, stats.current_balance)
    end

    # Send transaction (placeholder)
    "withdraw_signature_#{Random::Secure.hex(16)}"
  end

  # Private helper methods

  private def validate_donation(amount : Lamports)
    min = Lamports.new(MIN_DONATION)
    max = Lamports.new(MAX_DONATION)

    if amount < min
      raise DonationTooSmallError.new(amount, min)
    end

    if amount > max
      raise DonationTooLargeError.new(amount, max)
    end
  end
end

# =============================================================================
# Utility Functions
# =============================================================================

# Convert SOL to lamports
def sol(amount : Float64) : Lamports
  Lamports.from_sol(amount)
end

# Calculate donation percentage
def donation_percentage(donor_amount : Lamports, total_amount : Lamports) : Float64
  return 0.0 if total_amount.value == 0
  (donor_amount.value.to_f64 / total_amount.value.to_f64) * 100.0
end

# Format time ago
def format_time_ago(timestamp : Int64) : String
  now = Time.utc.to_unix
  diff = now - timestamp

  days = diff / 86400
  hours = (diff % 86400) / 3600
  minutes = (diff % 3600) / 60

  if days > 0
    "#{days} days ago"
  elsif hours > 0
    "#{hours} hours ago"
  elsif minutes > 0
    "#{minutes} minutes ago"
  else
    "just now"
  end
end

# =============================================================================
# Example Usage
# =============================================================================

if PROGRAM_NAME == __FILE__
  puts "=== Crystal Solana Donation Client ==="

  # Create client
  client = DonationClient.new
  puts "✓ Client created"

  # Example donor
  donor = "DonorPubkey123..."

  # Make donation
  begin
    result = client.donate(donor, amount: 0.5)
    puts "\n✓ Donation successful:"
    puts result
  rescue ex : DonationError
    puts "✗ Donation failed: #{ex.message}"
  end

  # Get vault stats
  stats = client.vault_stats
  puts "\n✓ Vault statistics:"
  puts stats

  # Get donor info
  info = client.donor_info(donor)
  puts "\n✓ Donor information:"
  puts info

  # Check tier progression
  if needed = info.lamports_to_next_tier
    puts "\n💡 Donate #{needed.to_sol.round(4)} more SOL to reach the next tier!"
  else
    puts "\n🎉 Congratulations! You've reached the maximum tier!"
  end
end
