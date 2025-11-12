{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE TypeFamilies        #-}
{-# LANGUAGE TypeOperators       #-}

-- | Plutus Donation Contract for Cardano
-- A secure donation system with donor tier tracking and admin controls
module DonationContract where

import           PlutusTx.Prelude
import qualified PlutusTx
import           Plutus.V2.Ledger.Api
import           Plutus.V2.Ledger.Contexts
import qualified Plutus.Script.Utils.V2.Scripts as Scripts
import           Plutus.Script.Utils.V2.Typed.Scripts
import           Ledger.Ada                        as Ada
import qualified Prelude                           as Haskell
import           GHC.Generics                      (Generic)
import           Data.Aeson                        (FromJSON, ToJSON)

-- | Donor tier levels based on contribution
data DonorTier = None | Bronze | Silver | Gold | Platinum
    deriving (Haskell.Show, Generic, FromJSON, ToJSON, Haskell.Eq)

PlutusTx.unstableMakeIsData ''DonorTier

-- | Contract parameters set at deployment
data DonationParams = DonationParams
    { dpAdmin       :: PaymentPubKeyHash  -- ^ Contract administrator
    , dpMinDonation :: Integer            -- ^ Minimum donation in lovelace
    , dpMaxDonation :: Integer            -- ^ Maximum donation in lovelace
    } deriving (Haskell.Show, Generic, FromJSON, ToJSON)

PlutusTx.makeLift ''DonationParams

-- | Contract datum - state stored with UTxO
data DonationDatum = DonationDatum
    { ddTotalDonations :: Integer                    -- ^ Total donations received
    , ddDonorAmounts   :: [(PaymentPubKeyHash, Integer)]  -- ^ Donor contributions
    , ddDonorCount     :: Integer                    -- ^ Number of unique donors
    , ddPaused         :: Bool                       -- ^ Contract pause state
    } deriving (Haskell.Show, Generic, FromJSON, ToJSON)

PlutusTx.unstableMakeIsData ''DonationDatum

-- | Contract redeemer - actions that can be performed
data DonationRedeemer
    = Donate Integer              -- ^ Make a donation
    | Withdraw Integer            -- ^ Withdraw funds (admin only)
    | EmergencyWithdraw           -- ^ Withdraw all funds (admin only)
    | Pause                       -- ^ Pause contract (admin only)
    | Unpause                     -- ^ Unpause contract (admin only)
    deriving (Haskell.Show, Generic, FromJSON, ToJSON)

PlutusTx.unstableMakeIsData ''DonationRedeemer

-- | Calculate donor tier based on total contribution
{-# INLINABLE calculateTier #-}
calculateTier :: Integer -> DonorTier
calculateTier amount
    | amount >= 10_000_000  = Platinum  -- 10+ ADA
    | amount >= 1_000_000   = Gold      -- 1+ ADA
    | amount >= 100_000     = Silver    -- 0.1+ ADA
    | amount >= 10_000      = Bronze    -- 0.01+ ADA
    | otherwise             = None

-- | Get donor's current amount
{-# INLINABLE getDonorAmount #-}
getDonorAmount :: PaymentPubKeyHash -> [(PaymentPubKeyHash, Integer)] -> Integer
getDonorAmount donor donors = case lookup donor donors of
    Just amount -> amount
    Nothing     -> 0

-- | Update or add donor amount
{-# INLINABLE updateDonorAmount #-}
updateDonorAmount :: PaymentPubKeyHash -> Integer -> [(PaymentPubKeyHash, Integer)] -> [(PaymentPubKeyHash, Integer)]
updateDonorAmount donor newAmount [] = [(donor, newAmount)]
updateDonorAmount donor newAmount ((d, amt):rest)
    | d == donor = (d, newAmount) : rest
    | otherwise  = (d, amt) : updateDonorAmount donor newAmount rest

-- | Main validator function
{-# INLINABLE mkValidator #-}
mkValidator :: DonationParams -> DonationDatum -> DonationRedeemer -> ScriptContext -> Bool
mkValidator params datum redeemer ctx =
    case redeemer of
        Donate amount ->
            traceIfFalse "Contract is paused" (not $ ddPaused datum) &&
            traceIfFalse "Donation too small" (amount >= dpMinDonation params) &&
            traceIfFalse "Donation too large" (amount <= dpMaxDonation params) &&
            traceIfFalse "Invalid donation amount" (amount > 0) &&
            traceIfFalse "Incorrect output datum" checkDonateOutput

        Withdraw amount ->
            traceIfFalse "Not admin" isAdmin &&
            traceIfFalse "Invalid withdrawal amount" (amount > 0) &&
            traceIfFalse "Insufficient balance" (amount <= getTotalValue inputValue)

        EmergencyWithdraw ->
            traceIfFalse "Not admin" isAdmin

        Pause ->
            traceIfFalse "Not admin" isAdmin &&
            traceIfFalse "Already paused" (not $ ddPaused datum)

        Unpause ->
            traceIfFalse "Not admin" isAdmin &&
            traceIfFalse "Not paused" (ddPaused datum)

  where
    info :: TxInfo
    info = scriptContextTxInfo ctx

    inputValue :: Value
    inputValue = case findOwnInput ctx of
        Just txInInfo -> txOutValue $ txInInfoResolved txInInfo
        Nothing       -> traceError "Input not found"

    outputDatum :: DonationDatum
    outputDatum = case getContinuingOutputs ctx of
        [o] -> case txOutDatum o of
            OutputDatum (Datum d) -> case PlutusTx.fromBuiltinData d of
                Just datum' -> datum'
                Nothing     -> traceError "Invalid output datum"
            _ -> traceError "No output datum"
        _ -> traceError "Expected exactly one continuing output"

    isAdmin :: Bool
    isAdmin = txSignedBy info $ unPaymentPubKeyHash $ dpAdmin params

    donor :: PaymentPubKeyHash
    donor = case txInfoSignatories info of
        [pkh] -> PaymentPubKeyHash pkh
        _     -> traceError "Expected exactly one signatory"

    checkDonateOutput :: Bool
    checkDonateOutput =
        let currentAmount = getDonorAmount donor (ddDonorAmounts datum)
            newAmount = case redeemer of
                Donate amt -> currentAmount + amt
                _          -> currentAmount
            newDonors = updateDonorAmount donor newAmount (ddDonorAmounts datum)
            isNewDonor = currentAmount == 0
            newCount = if isNewDonor then ddDonorCount datum + 1 else ddDonorCount datum
            expectedDatum = DonationDatum
                { ddTotalDonations = ddTotalDonations datum + (case redeemer of Donate amt -> amt; _ -> 0)
                , ddDonorAmounts   = newDonors
                , ddDonorCount     = newCount
                , ddPaused         = ddPaused datum
                }
        in outputDatum == expectedDatum

    getTotalValue :: Value -> Integer
    getTotalValue v = Ada.getLovelace $ Ada.fromValue v

-- | Typed validator
data Donating
instance ValidatorTypes Donating where
    type instance DatumType Donating = DonationDatum
    type instance RedeemerType Donating = DonationRedeemer

typedValidator :: DonationParams -> TypedValidator Donating
typedValidator params = mkTypedValidator @Donating
    ($$(PlutusTx.compile [|| mkValidator ||]) `PlutusTx.applyCode` PlutusTx.liftCode params)
    $$(PlutusTx.compile [|| wrap ||])
  where
    wrap = wrapValidator @DonationDatum @DonationRedeemer

-- | Validator script
validator :: DonationParams -> Validator
validator = Scripts.validatorScript . typedValidator

-- | Validator hash
validatorHash :: DonationParams -> ValidatorHash
validatorHash = Scripts.validatorHash . typedValidator

-- | Validator address
validatorAddress :: DonationParams -> Address
validatorAddress = scriptHashAddress . validatorHash

-- | Helper functions for off-chain code

-- | Initial datum for contract deployment
initialDatum :: DonationDatum
initialDatum = DonationDatum
    { ddTotalDonations = 0
    , ddDonorAmounts   = []
    , ddDonorCount     = 0
    , ddPaused         = False
    }

-- | Get donor tier
getDonorTier :: PaymentPubKeyHash -> DonationDatum -> DonorTier
getDonorTier donor datum = calculateTier $ getDonorAmount donor (ddDonorAmounts datum)

-- | Check if contract is paused
isPaused :: DonationDatum -> Bool
isPaused = ddPaused

-- | Get total donations
getTotalDonations :: DonationDatum -> Integer
getTotalDonations = ddTotalDonations

-- | Get donor count
getDonorCount :: DonationDatum -> Integer
getDonorCount = ddDonorCount

-- | Serialize script for deployment
donationScript :: DonationParams -> Haskell.String
donationScript params = Haskell.show $ Scripts.validatorScript $ typedValidator params
