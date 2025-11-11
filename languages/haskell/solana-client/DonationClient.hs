{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RecordWildCards #-}

-- | Haskell client for Solana Donation Contract
--
-- This module provides a purely functional interface for interacting
-- with the Solana donation smart contract using strong types and
-- monadic error handling.
module DonationClient
  ( -- * Types
    Pubkey(..)
  , Lamports(..)
  , DonorTier(..)
  , DonationResult(..)
  , VaultStats(..)
  , DonationError(..)

  -- * Operations
  , donate
  , getVaultStats
  , getDonorInfo
  , withdrawFunds

  -- * Utilities
  , sol
  , lamportsToSol
  , solToLamports
  , calculateTier
  ) where

import Data.Aeson (ToJSON, FromJSON, encode, decode)
import GHC.Generics (Generic)
import Control.Monad.Except (ExceptT, runExceptT, throwError)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Word (Word64)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as BL

-- ============================================================================
-- Core Types
-- ============================================================================

-- | Public key on Solana blockchain
newtype Pubkey = Pubkey ByteString
  deriving (Eq, Show, Generic)

instance ToJSON Pubkey
instance FromJSON Pubkey

-- | Amount in lamports (1 SOL = 1,000,000,000 lamports)
newtype Lamports = Lamports { unLamports :: Word64 }
  deriving (Eq, Ord, Show, Num, Generic)

instance ToJSON Lamports
instance FromJSON Lamports

-- | Donor tier classification
data DonorTier
  = Bronze    -- ^ >= 0.001 SOL
  | Silver    -- ^ >= 0.1 SOL
  | Gold      -- ^ >= 1 SOL
  | Platinum  -- ^ >= 10 SOL
  deriving (Eq, Ord, Show, Enum, Bounded, Generic)

instance ToJSON DonorTier
instance FromJSON DonorTier

-- | Result of a donation operation
data DonationResult = DonationResult
  { drSignature     :: Text
  , drAmount        :: Lamports
  , drDonor         :: Pubkey
  , drNewTier       :: DonorTier
  , drTotalDonated  :: Lamports
  } deriving (Eq, Show, Generic)

instance ToJSON DonationResult
instance FromJSON DonationResult

-- | Vault statistics
data VaultStats = VaultStats
  { vsAdmin              :: Pubkey
  , vsTotalDonated       :: Lamports
  , vsTotalWithdrawn     :: Lamports
  , vsCurrentBalance     :: Lamports
  , vsDonationCount      :: Word64
  , vsUniqueDonors       :: Word64
  , vsIsPaused           :: Bool
  , vsMinDonationAmount  :: Lamports
  , vsMaxDonationAmount  :: Lamports
  } deriving (Eq, Show, Generic)

instance ToJSON VaultStats
instance FromJSON VaultStats

-- | Donor information
data DonorInfo = DonorInfo
  { diDonor                 :: Pubkey
  , diTotalDonated          :: Lamports
  , diDonationCount         :: Word64
  , diLastDonationTimestamp :: Int
  , diTier                  :: DonorTier
  } deriving (Eq, Show, Generic)

instance ToJSON DonorInfo
instance FromJSON DonorInfo

-- | Donation-specific errors
data DonationError
  = DonationTooSmall Lamports Lamports  -- ^ Actual, Minimum
  | DonationTooLarge Lamports Lamports  -- ^ Actual, Maximum
  | ContractPaused
  | InsufficientFunds Lamports Lamports -- ^ Required, Available
  | Unauthorized Pubkey Pubkey          -- ^ Actual, Expected
  | NetworkError Text
  | ParseError Text
  | InvalidPublicKey Text
  deriving (Eq, Show)

-- | Monad stack for donation operations
type DonationM a = ExceptT DonationError IO a

-- ============================================================================
-- Constants
-- ============================================================================

minDonation :: Lamports
minDonation = Lamports 1_000_000  -- 0.001 SOL

maxDonation :: Lamports
maxDonation = Lamports 100_000_000_000  -- 100 SOL

lamportsPerSol :: Word64
lamportsPerSol = 1_000_000_000

tierBronze :: Lamports
tierBronze = Lamports 1_000_000

tierSilver :: Lamports
tierSilver = Lamports 100_000_000

tierGold :: Lamports
tierGold = Lamports 1_000_000_000

tierPlatinum :: Lamports
tierPlatinum = Lamports 10_000_000_000

-- ============================================================================
-- Core Functions
-- ============================================================================

-- | Convert SOL to lamports
sol :: Double -> Lamports
sol amount = Lamports $ round (amount * fromIntegral lamportsPerSol)

-- | Convert lamports to SOL
lamportsToSol :: Lamports -> Double
lamportsToSol (Lamports l) = fromIntegral l / fromIntegral lamportsPerSol

-- | Convert SOL to lamports (alias for `sol`)
solToLamports :: Double -> Lamports
solToLamports = sol

-- | Calculate donor tier based on total donations
calculateTier :: Lamports -> DonorTier
calculateTier donated
  | donated >= tierPlatinum = Platinum
  | donated >= tierGold     = Gold
  | donated >= tierSilver   = Silver
  | otherwise               = Bronze

-- | Validate donation amount
validateDonation :: Lamports -> Lamports -> Lamports -> Either DonationError ()
validateDonation amount minAmount maxAmount
  | amount < minAmount = Left $ DonationTooSmall amount minAmount
  | amount > maxAmount = Left $ DonationTooLarge amount maxAmount
  | otherwise          = Right ()

-- ============================================================================
-- Client Operations
-- ============================================================================

-- | Make a donation to the vault
--
-- >>> donate myKeypair (sol 0.5)
-- Right (DonationResult {...})
donate :: Pubkey -> Lamports -> DonationM DonationResult
donate donor amount = do
  -- Validate donation amount
  case validateDonation amount minDonation maxDonation of
    Left err -> throwError err
    Right () -> pure ()

  -- Check if contract is paused
  stats <- getVaultStats
  if vsIsPaused stats
    then throwError ContractPaused
    else pure ()

  -- Build and send transaction (simplified)
  signature <- sendTransaction donor amount

  -- Get updated donor info
  donorInfo <- getDonorInfo donor

  pure DonationResult
    { drSignature    = signature
    , drAmount       = amount
    , drDonor        = donor
    , drNewTier      = diTier donorInfo
    , drTotalDonated = diTotalDonated donorInfo
    }

-- | Get vault statistics
getVaultStats :: DonationM VaultStats
getVaultStats = do
  -- Call RPC endpoint (simplified)
  response <- callRPC "getVaultStats" []
  case parseVaultStats response of
    Nothing -> throwError $ ParseError "Failed to parse vault stats"
    Just stats -> pure stats

-- | Get donor information
getDonorInfo :: Pubkey -> DonationM DonorInfo
getDonorInfo donor = do
  -- Call RPC endpoint (simplified)
  response <- callRPC "getDonorInfo" [donor]
  case parseDonorInfo response of
    Nothing -> throwError $ ParseError "Failed to parse donor info"
    Just info -> pure info

-- | Withdraw funds (admin only)
withdrawFunds :: Pubkey -> Lamports -> DonationM Text
withdrawFunds admin amount = do
  stats <- getVaultStats

  -- Check authorization
  if admin /= vsAdmin stats
    then throwError $ Unauthorized admin (vsAdmin stats)
    else pure ()

  -- Check sufficient funds
  if amount > vsCurrentBalance stats
    then throwError $ InsufficientFunds amount (vsCurrentBalance stats)
    else pure ()

  -- Send withdrawal transaction
  sendTransaction admin amount

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- | Send a transaction to the blockchain (placeholder)
sendTransaction :: Pubkey -> Lamports -> DonationM Text
sendTransaction _donor _amount = pure "signature_placeholder"

-- | Call RPC endpoint (placeholder)
callRPC :: Text -> [Pubkey] -> DonationM BL.ByteString
callRPC _method _params = pure "{}"

-- | Parse vault stats from JSON
parseVaultStats :: BL.ByteString -> Maybe VaultStats
parseVaultStats = decode

-- | Parse donor info from JSON
parseDonorInfo :: BL.ByteString -> Maybe DonorInfo
parseDonorInfo = decode

-- ============================================================================
-- Pure Utility Functions
-- ============================================================================

-- | Calculate next tier threshold
nextTierThreshold :: DonorTier -> Maybe Lamports
nextTierThreshold Bronze   = Just tierSilver
nextTierThreshold Silver   = Just tierGold
nextTierThreshold Gold     = Just tierPlatinum
nextTierThreshold Platinum = Nothing

-- | Calculate lamports needed to reach next tier
lamportsToNextTier :: Lamports -> DonorTier -> Maybe Lamports
lamportsToNextTier current tier = do
  nextThreshold <- nextTierThreshold tier
  if current >= nextThreshold
    then Nothing
    else Just (nextThreshold - current)

-- | Get tier emoji representation
tierEmoji :: DonorTier -> Text
tierEmoji Bronze   = "🥉"
tierEmoji Silver   = "🥈"
tierEmoji Gold     = "🥇"
tierEmoji Platinum = "💎"

-- | Get tier name
tierName :: DonorTier -> Text
tierName = T.pack . show

-- | Calculate percentage of total donations
donationPercentage :: Lamports -> Lamports -> Double
donationPercentage (Lamports donor) (Lamports total)
  | total == 0 = 0.0
  | otherwise  = (fromIntegral donor / fromIntegral total) * 100.0

-- ============================================================================
-- Monadic Utilities
-- ============================================================================

-- | Run a donation operation
runDonation :: DonationM a -> IO (Either DonationError a)
runDonation = runExceptT

-- | Format donation error for display
formatError :: DonationError -> Text
formatError (DonationTooSmall actual minAmount) =
  "Donation of " <> T.pack (show actual) <> " is below minimum of " <> T.pack (show minAmount)
formatError (DonationTooLarge actual maxAmount) =
  "Donation of " <> T.pack (show actual) <> " exceeds maximum of " <> T.pack (show maxAmount)
formatError ContractPaused =
  "Contract is currently paused"
formatError (InsufficientFunds required available) =
  "Insufficient funds: need " <> T.pack (show required) <> ", have " <> T.pack (show available)
formatError (Unauthorized actual expected) =
  "Unauthorized: expected " <> T.pack (show expected) <> ", got " <> T.pack (show actual)
formatError (NetworkError msg) =
  "Network error: " <> msg
formatError (ParseError msg) =
  "Parse error: " <> msg
formatError (InvalidPublicKey msg) =
  "Invalid public key: " <> msg
