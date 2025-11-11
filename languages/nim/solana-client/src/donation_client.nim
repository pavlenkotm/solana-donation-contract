## Nim Solana Donation Client
##
## A high-performance client for interacting with the Solana donation
## smart contract. Combines Python-like syntax with C-like performance.
##
## Example:
##   let client = newDonationClient()
##   let result = client.donate(donorPubkey, 0.5.SOL)
##   echo "Signature: ", result.signature

import std/[options, times, strformat, json, tables, math]
import std/httpclient
import std/asyncdispatch

# =============================================================================
# Constants
# =============================================================================

const
  LamportsPerSol* = 1_000_000_000'u64
  MinDonation* = 1_000_000'u64  # 0.001 SOL
  MaxDonation* = 100_000_000_000'u64  # 100 SOL

  TierBronze* = 1_000_000'u64
  TierSilver* = 100_000_000'u64
  TierGold* = 1_000_000_000'u64
  TierPlatinum* = 10_000_000_000'u64

# =============================================================================
# Types
# =============================================================================

type
  Pubkey* = distinct string
    ## Solana public key (base58 encoded)

  Lamports* = distinct uint64
    ## Amount in lamports (1 SOL = 1,000,000,000 lamports)

  SOL* = distinct float64
    ## Amount in SOL

  DonorTier* = enum
    ## Donor tier classification based on total donations
    Bronze = "bronze"      ## >= 0.001 SOL
    Silver = "silver"      ## >= 0.1 SOL
    Gold = "gold"          ## >= 1 SOL
    Platinum = "platinum"  ## >= 10 SOL

  DonationResult* = object
    ## Result of a donation operation
    signature*: string
    amount*: Lamports
    donor*: Pubkey
    newTier*: DonorTier
    totalDonated*: Lamports

  VaultStats* = object
    ## Vault statistics
    admin*: Pubkey
    totalDonated*: Lamports
    totalWithdrawn*: Lamports
    currentBalance*: Lamports
    donationCount*: uint64
    uniqueDonors*: uint64
    isPaused*: bool
    minDonationAmount*: Lamports
    maxDonationAmount*: Lamports

  DonorInfo* = object
    ## Individual donor information
    donor*: Pubkey
    totalDonated*: Lamports
    donationCount*: uint64
    lastDonationTimestamp*: int64
    tier*: DonorTier

  DonationError* = object of CatchableError
    ## Base exception for donation errors

  DonationTooSmallError* = object of DonationError
  DonationTooLargeError* = object of DonationError
  ContractPausedError* = object of DonationError
  InsufficientFundsError* = object of DonationError
  UnauthorizedError* = object of DonationError

  DonationClient* = ref object
    ## Main client for interacting with donation contract
    rpcUrl: string
    programId: Pubkey
    httpClient: HttpClient

# =============================================================================
# Converters
# =============================================================================

converter toPubkey*(s: string): Pubkey = Pubkey(s)
converter toString*(p: Pubkey): string = string(p)
converter toLamports*(u: uint64): Lamports = Lamports(u)
converter toUint64*(l: Lamports): uint64 = uint64(l)
converter toSOL*(f: float64): SOL = SOL(f)
converter toFloat64*(s: SOL): float64 = float64(s)

# =============================================================================
# Utility Functions
# =============================================================================

proc sol*(amount: float64): Lamports =
  ## Convert SOL to lamports
  ##
  ## Example:
  ##   let lamports = sol(0.5)  # 500_000_000 lamports
  result = (amount * LamportsPerSol.float64).uint64.Lamports

proc toSOL*(lamports: Lamports): float64 =
  ## Convert lamports to SOL
  ##
  ## Example:
  ##   let solAmount = 1_000_000_000.Lamports.toSOL()  # 1.0 SOL
  result = lamports.uint64.float64 / LamportsPerSol.float64

proc calculateTier*(totalDonated: Lamports): DonorTier =
  ## Calculate donor tier based on total donations
  ##
  ## Example:
  ##   let tier = calculateTier(10_000_000_000.Lamports)  # Platinum
  if totalDonated.uint64 >= TierPlatinum:
    Platinum
  elif totalDonated.uint64 >= TierGold:
    Gold
  elif totalDonated.uint64 >= TierSilver:
    Silver
  else:
    Bronze

proc tierEmoji*(tier: DonorTier): string =
  ## Get emoji representation of tier
  ##
  ## Example:
  ##   echo tierEmoji(Platinum)  # "💎"
  case tier
  of Bronze: "🥉"
  of Silver: "🥈"
  of Gold: "🥇"
  of Platinum: "💎"

proc tierName*(tier: DonorTier): string =
  ## Get name of tier
  ##
  ## Example:
  ##   echo tierName(Gold)  # "Gold"
  $tier

proc nextTierThreshold*(currentTier: DonorTier): Option[tuple[tier: DonorTier, threshold: Lamports]] =
  ## Get next tier and its threshold
  ##
  ## Example:
  ##   let next = nextTierThreshold(Bronze)
  ##   if next.isSome:
  ##     echo "Next tier: ", next.get.tier
  case currentTier
  of Bronze:
    some((tier: Silver, threshold: TierSilver.Lamports))
  of Silver:
    some((tier: Gold, threshold: TierGold.Lamports))
  of Gold:
    some((tier: Platinum, threshold: TierPlatinum.Lamports))
  of Platinum:
    none(tuple[tier: DonorTier, threshold: Lamports])

proc lamportsToNextTier*(currentDonated: Lamports, currentTier: DonorTier): Option[Lamports] =
  ## Calculate lamports needed to reach next tier
  ##
  ## Example:
  ##   let needed = lamportsToNextTier(50_000_000.Lamports, Bronze)
  let nextTier = nextTierThreshold(currentTier)
  if nextTier.isNone:
    return none(Lamports)

  let threshold = nextTier.get.threshold
  if currentDonated.uint64 >= threshold.uint64:
    none(Lamports)
  else:
    some((threshold.uint64 - currentDonated.uint64).Lamports)

# =============================================================================
# Validation Functions
# =============================================================================

proc validateDonation*(amount: Lamports, minAmount, maxAmount: Lamports) =
  ## Validate donation amount
  ##
  ## Raises:
  ##   DonationTooSmallError: If amount < minAmount
  ##   DonationTooLargeError: If amount > maxAmount
  if amount.uint64 < minAmount.uint64:
    raise newException(DonationTooSmallError,
      &"Donation of {amount} is below minimum of {minAmount}")

  if amount.uint64 > maxAmount.uint64:
    raise newException(DonationTooLargeError,
      &"Donation of {amount} exceeds maximum of {maxAmount}")

proc checkNotPaused*(stats: VaultStats) =
  ## Check if contract is not paused
  ##
  ## Raises:
  ##   ContractPausedError: If contract is paused
  if stats.isPaused:
    raise newException(ContractPausedError, "Contract is currently paused")

proc checkSufficientFunds*(required, available: Lamports) =
  ## Check if sufficient funds are available
  ##
  ## Raises:
  ##   InsufficientFundsError: If available < required
  if available.uint64 < required.uint64:
    raise newException(InsufficientFundsError,
      &"Insufficient funds: need {required}, have {available}")

proc checkAuthorization*(caller, expected: Pubkey) =
  ## Check if caller is authorized
  ##
  ## Raises:
  ##   UnauthorizedError: If caller != expected
  if caller.string != expected.string:
    raise newException(UnauthorizedError,
      &"Unauthorized: expected {expected}, got {caller}")

# =============================================================================
# Client Implementation
# =============================================================================

proc newDonationClient*(
  rpcUrl: string = "https://api.devnet.solana.com",
  programId: string = "DoNaT1on111111111111111111111111111111111111"
): DonationClient =
  ## Create a new donation client
  ##
  ## Example:
  ##   let client = newDonationClient()
  ##   let client2 = newDonationClient("https://api.mainnet-beta.solana.com")
  result = DonationClient(
    rpcUrl: rpcUrl,
    programId: programId.Pubkey,
    httpClient: newHttpClient()
  )

proc donate*(
  client: DonationClient,
  donor: Pubkey,
  amount: SOL
): DonationResult =
  ## Make a donation to the vault
  ##
  ## Args:
  ##   donor: Donor's public key
  ##   amount: Amount in SOL
  ##
  ## Returns:
  ##   DonationResult with signature and updated info
  ##
  ## Raises:
  ##   DonationTooSmallError, DonationTooLargeError, ContractPausedError
  ##
  ## Example:
  ##   let result = client.donate(donorPubkey, 0.5.SOL)
  ##   echo "Signature: ", result.signature

  let lamports = sol(amount.float64)

  # Validate donation amount
  validateDonation(lamports, MinDonation.Lamports, MaxDonation.Lamports)

  # Check if contract is paused
  let stats = client.getVaultStats()
  checkNotPaused(stats)

  # Send transaction (placeholder)
  let signature = "signature_" & $hash(donor.string)

  # Get updated donor info (placeholder)
  let donorInfo = client.getDonorInfo(donor)

  result = DonationResult(
    signature: signature,
    amount: lamports,
    donor: donor,
    newTier: donorInfo.tier,
    totalDonated: donorInfo.totalDonated
  )

proc getVaultStats*(client: DonationClient): VaultStats =
  ## Get vault statistics
  ##
  ## Returns:
  ##   VaultStats with current vault information
  ##
  ## Example:
  ##   let stats = client.getVaultStats()
  ##   echo "Total donated: ", stats.totalDonated.toSOL(), " SOL"

  # Placeholder implementation - would call RPC endpoint
  result = VaultStats(
    admin: "Admin123...".Pubkey,
    totalDonated: 1_000_000_000'u64.Lamports,
    totalWithdrawn: 0'u64.Lamports,
    currentBalance: 1_000_000_000'u64.Lamports,
    donationCount: 10'u64,
    uniqueDonors: 5'u64,
    isPaused: false,
    minDonationAmount: MinDonation.Lamports,
    maxDonationAmount: MaxDonation.Lamports
  )

proc getDonorInfo*(client: DonationClient, donor: Pubkey): DonorInfo =
  ## Get donor information
  ##
  ## Args:
  ##   donor: Donor's public key
  ##
  ## Returns:
  ##   DonorInfo with donor statistics and tier
  ##
  ## Example:
  ##   let info = client.getDonorInfo(donorPubkey)
  ##   echo "Tier: ", info.tier.tierEmoji()

  # Placeholder implementation - would call RPC endpoint
  let totalDonated = 500_000_000'u64.Lamports
  result = DonorInfo(
    donor: donor,
    totalDonated: totalDonated,
    donationCount: 3'u64,
    lastDonationTimestamp: getTime().toUnix(),
    tier: calculateTier(totalDonated)
  )

proc withdraw*(
  client: DonationClient,
  admin: Pubkey,
  amount: SOL
): string =
  ## Withdraw funds from the vault (admin only)
  ##
  ## Args:
  ##   admin: Admin's public key
  ##   amount: Amount to withdraw in SOL
  ##
  ## Returns:
  ##   Transaction signature
  ##
  ## Raises:
  ##   UnauthorizedError, InsufficientFundsError
  ##
  ## Example:
  ##   let signature = client.withdraw(adminPubkey, 1.0.SOL)

  let lamports = sol(amount.float64)

  # Get vault stats
  let stats = client.getVaultStats()

  # Check authorization
  checkAuthorization(admin, stats.admin)

  # Check sufficient funds
  checkSufficientFunds(lamports, stats.currentBalance)

  # Send transaction (placeholder)
  result = "withdraw_signature_" & $hash(admin.string)

# =============================================================================
# Formatting and Display
# =============================================================================

proc `$`*(tier: DonorTier): string =
  ## String representation of tier
  tierName(tier) & " " & tierEmoji(tier)

proc `$`*(lamports: Lamports): string =
  ## String representation of lamports
  &"{lamports.toSOL():.9f} SOL ({lamports.uint64} lamports)"

proc `$`*(result: DonationResult): string =
  ## String representation of donation result
  &"""
Donation Result:
  Signature: {result.signature}
  Amount: {result.amount}
  Donor: {result.donor}
  New Tier: {result.newTier}
  Total Donated: {result.totalDonated}
"""

proc `$`*(stats: VaultStats): string =
  ## String representation of vault stats
  &"""
Vault Statistics:
  Admin: {stats.admin}
  Total Donated: {stats.totalDonated}
  Total Withdrawn: {stats.totalWithdrawn}
  Current Balance: {stats.currentBalance}
  Donations: {stats.donationCount}
  Unique Donors: {stats.uniqueDonors}
  Paused: {stats.isPaused}
"""

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  echo "=== Nim Solana Donation Client ==="

  # Create client
  let client = newDonationClient()
  echo "✓ Client created"

  # Example donor
  let donor = "DonorPubkey123...".Pubkey

  # Make donation
  try:
    let result = client.donate(donor, 0.5.SOL)
    echo "\n✓ Donation successful:"
    echo result
  except DonationError as e:
    echo "✗ Donation failed: ", e.msg

  # Get vault stats
  let stats = client.getVaultStats()
  echo "\n✓ Vault stats:"
  echo stats

  # Get donor info
  let info = client.getDonorInfo(donor)
  echo "\n✓ Donor info:"
  echo &"  Tier: {info.tier}"
  echo &"  Total: {info.totalDonated}"
  echo &"  Count: {info.donationCount}"

  # Check next tier
  let nextTier = lamportsToNextTier(info.totalDonated, info.tier)
  if nextTier.isSome:
    echo &"  Need {nextTier.get.toSOL():.4f} SOL for next tier"
  else:
    echo "  Already at max tier! 💎"
