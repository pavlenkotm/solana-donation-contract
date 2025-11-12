package donation

import (
	"fmt"

	"github.com/cosmos/cosmos-sdk/codec"
	storetypes "github.com/cosmos/cosmos-sdk/store/types"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
)

// Keeper handles donation module state
type Keeper struct {
	cdc      codec.BinaryCodec
	storeKey storetypes.StoreKey
}

// NewKeeper creates a new donation Keeper
func NewKeeper(
	cdc codec.BinaryCodec,
	storeKey storetypes.StoreKey,
) Keeper {
	return Keeper{
		cdc:      cdc,
		storeKey: storeKey,
	}
}

// DonorTier represents donor tier levels
type DonorTier uint8

const (
	TierNone     DonorTier = 0
	TierBronze   DonorTier = 1 // 0.01+ ATOM
	TierSilver   DonorTier = 2 // 0.1+ ATOM
	TierGold     DonorTier = 3 // 1+ ATOM
	TierPlatinum DonorTier = 4 // 10+ ATOM
)

// DonationState stores the contract state
type DonationState struct {
	Admin          string
	TotalDonations sdk.Coins
	DonorCount     uint64
	MinDonation    sdk.Coins
	MaxDonation    sdk.Coins
	Paused         bool
	Initialized    bool
}

// DonorRecord stores donor information
type DonorRecord struct {
	Address       string
	TotalDonated  sdk.Coins
	Tier          DonorTier
	FirstDonation int64
}

// Keys for store
var (
	StateKey       = []byte{0x01}
	DonorKeyPrefix = []byte{0x02}
)

// GetDonorKey returns the store key for a donor
func GetDonorKey(addr string) []byte {
	return append(DonorKeyPrefix, []byte(addr)...)
}

// Initialize initializes the donation module
func (k Keeper) Initialize(
	ctx sdk.Context,
	admin string,
	minDonation sdk.Coins,
	maxDonation sdk.Coins,
) error {
	state, found := k.GetState(ctx)
	if found && state.Initialized {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidRequest, "already initialized")
	}

	if minDonation.IsZero() || !minDonation.IsValid() {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidCoins, "invalid min donation")
	}

	if !maxDonation.IsValid() || !maxDonation.IsAllGT(minDonation) {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidCoins, "max must be greater than min")
	}

	newState := DonationState{
		Admin:          admin,
		TotalDonations: sdk.NewCoins(),
		DonorCount:     0,
		MinDonation:    minDonation,
		MaxDonation:    maxDonation,
		Paused:         false,
		Initialized:    true,
	}

	k.SetState(ctx, newState)

	ctx.EventManager().EmitEvent(
		sdk.NewEvent(
			"donation_initialized",
			sdk.NewAttribute("admin", admin),
			sdk.NewAttribute("min_donation", minDonation.String()),
			sdk.NewAttribute("max_donation", maxDonation.String()),
		),
	)

	return nil
}

// Donate processes a donation
func (k Keeper) Donate(
	ctx sdk.Context,
	donor string,
	amount sdk.Coins,
) error {
	state, found := k.GetState(ctx)
	if !found || !state.Initialized {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidRequest, "not initialized")
	}

	if state.Paused {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidRequest, "contract is paused")
	}

	// Validate donation amount
	if !amount.IsValid() || amount.IsZero() {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidCoins, "invalid donation amount")
	}

	if !amount.IsAllGTE(state.MinDonation) {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidCoins, "donation too small")
	}

	if !state.MaxDonation.IsAllGTE(amount) {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidCoins, "donation too large")
	}

	// Get or create donor record
	donorRecord, found := k.GetDonor(ctx, donor)
	if !found {
		donorRecord = DonorRecord{
			Address:       donor,
			TotalDonated:  sdk.NewCoins(),
			Tier:          TierNone,
			FirstDonation: ctx.BlockTime().Unix(),
		}
		state.DonorCount++
	}

	// Update donor record
	donorRecord.TotalDonated = donorRecord.TotalDonated.Add(amount...)
	donorRecord.Tier = k.CalculateTier(donorRecord.TotalDonated)

	// Update state
	state.TotalDonations = state.TotalDonations.Add(amount...)

	// Save updates
	k.SetDonor(ctx, donorRecord)
	k.SetState(ctx, state)

	// Emit event
	ctx.EventManager().EmitEvent(
		sdk.NewEvent(
			"donation_received",
			sdk.NewAttribute("donor", donor),
			sdk.NewAttribute("amount", amount.String()),
			sdk.NewAttribute("total", donorRecord.TotalDonated.String()),
			sdk.NewAttribute("tier", fmt.Sprintf("%d", donorRecord.Tier)),
			sdk.NewAttribute("timestamp", fmt.Sprintf("%d", ctx.BlockTime().Unix())),
		),
	)

	return nil
}

// Withdraw allows admin to withdraw funds
func (k Keeper) Withdraw(
	ctx sdk.Context,
	admin string,
	amount sdk.Coins,
	recipient string,
) error {
	state, found := k.GetState(ctx)
	if !found || !state.Initialized {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidRequest, "not initialized")
	}

	if admin != state.Admin {
		return sdkerrors.Wrap(sdkerrors.ErrUnauthorized, "only admin can withdraw")
	}

	if !amount.IsValid() || amount.IsZero() {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidCoins, "invalid withdrawal amount")
	}

	// Emit event
	ctx.EventManager().EmitEvent(
		sdk.NewEvent(
			"withdrawal",
			sdk.NewAttribute("admin", admin),
			sdk.NewAttribute("amount", amount.String()),
			sdk.NewAttribute("recipient", recipient),
			sdk.NewAttribute("timestamp", fmt.Sprintf("%d", ctx.BlockTime().Unix())),
		),
	)

	return nil
}

// EmergencyWithdraw allows admin to withdraw all funds
func (k Keeper) EmergencyWithdraw(
	ctx sdk.Context,
	admin string,
	recipient string,
) (sdk.Coins, error) {
	state, found := k.GetState(ctx)
	if !found || !state.Initialized {
		return nil, sdkerrors.Wrap(sdkerrors.ErrInvalidRequest, "not initialized")
	}

	if admin != state.Admin {
		return nil, sdkerrors.Wrap(sdkerrors.ErrUnauthorized, "only admin can withdraw")
	}

	balance := state.TotalDonations

	// Emit event
	ctx.EventManager().EmitEvent(
		sdk.NewEvent(
			"emergency_withdrawal",
			sdk.NewAttribute("admin", admin),
			sdk.NewAttribute("amount", balance.String()),
			sdk.NewAttribute("recipient", recipient),
			sdk.NewAttribute("timestamp", fmt.Sprintf("%d", ctx.BlockTime().Unix())),
		),
	)

	return balance, nil
}

// Pause pauses the contract
func (k Keeper) Pause(ctx sdk.Context, admin string) error {
	state, found := k.GetState(ctx)
	if !found || !state.Initialized {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidRequest, "not initialized")
	}

	if admin != state.Admin {
		return sdkerrors.Wrap(sdkerrors.ErrUnauthorized, "only admin can pause")
	}

	if state.Paused {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidRequest, "already paused")
	}

	state.Paused = true
	k.SetState(ctx, state)

	ctx.EventManager().EmitEvent(
		sdk.NewEvent(
			"contract_paused",
			sdk.NewAttribute("admin", admin),
			sdk.NewAttribute("timestamp", fmt.Sprintf("%d", ctx.BlockTime().Unix())),
		),
	)

	return nil
}

// Unpause unpauses the contract
func (k Keeper) Unpause(ctx sdk.Context, admin string) error {
	state, found := k.GetState(ctx)
	if !found || !state.Initialized {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidRequest, "not initialized")
	}

	if admin != state.Admin {
		return sdkerrors.Wrap(sdkerrors.ErrUnauthorized, "only admin can unpause")
	}

	if !state.Paused {
		return sdkerrors.Wrap(sdkerrors.ErrInvalidRequest, "not paused")
	}

	state.Paused = false
	k.SetState(ctx, state)

	ctx.EventManager().EmitEvent(
		sdk.NewEvent(
			"contract_unpaused",
			sdk.NewAttribute("admin", admin),
			sdk.NewAttribute("timestamp", fmt.Sprintf("%d", ctx.BlockTime().Unix())),
		),
	)

	return nil
}

// Query functions

// GetState retrieves the donation state
func (k Keeper) GetState(ctx sdk.Context) (DonationState, bool) {
	store := ctx.KVStore(k.storeKey)
	bz := store.Get(StateKey)
	if bz == nil {
		return DonationState{}, false
	}

	var state DonationState
	k.cdc.MustUnmarshal(bz, &state)
	return state, true
}

// SetState stores the donation state
func (k Keeper) SetState(ctx sdk.Context, state DonationState) {
	store := ctx.KVStore(k.storeKey)
	bz := k.cdc.MustMarshal(&state)
	store.Set(StateKey, bz)
}

// GetDonor retrieves a donor record
func (k Keeper) GetDonor(ctx sdk.Context, addr string) (DonorRecord, bool) {
	store := ctx.KVStore(k.storeKey)
	bz := store.Get(GetDonorKey(addr))
	if bz == nil {
		return DonorRecord{}, false
	}

	var donor DonorRecord
	k.cdc.MustUnmarshal(bz, &donor)
	return donor, true
}

// SetDonor stores a donor record
func (k Keeper) SetDonor(ctx sdk.Context, donor DonorRecord) {
	store := ctx.KVStore(k.storeKey)
	bz := k.cdc.MustMarshal(&donor)
	store.Set(GetDonorKey(donor.Address), bz)
}

// GetAllDonors returns all donor records
func (k Keeper) GetAllDonors(ctx sdk.Context) []DonorRecord {
	store := ctx.KVStore(k.storeKey)
	iterator := sdk.KVStorePrefixIterator(store, DonorKeyPrefix)
	defer iterator.Close()

	donors := []DonorRecord{}
	for ; iterator.Valid(); iterator.Next() {
		var donor DonorRecord
		k.cdc.MustUnmarshal(iterator.Value(), &donor)
		donors = append(donors, donor)
	}

	return donors
}

// CalculateTier calculates the donor tier based on total contribution
func (k Keeper) CalculateTier(amount sdk.Coins) DonorTier {
	// Assuming ATOM with 6 decimals (uatom)
	const (
		ATOM             = 1_000_000
		BronzeThreshold  = 10_000        // 0.01 ATOM
		SilverThreshold  = 100_000       // 0.1 ATOM
		GoldThreshold    = 1_000_000     // 1 ATOM
		PlatinumThreshold = 10_000_000   // 10 ATOM
	)

	// Get total amount in base units
	totalAmount := amount.AmountOf("uatom").Int64()

	if totalAmount >= PlatinumThreshold {
		return TierPlatinum
	} else if totalAmount >= GoldThreshold {
		return TierGold
	} else if totalAmount >= SilverThreshold {
		return TierSilver
	} else if totalAmount >= BronzeThreshold {
		return TierBronze
	}

	return TierNone
}

// TierToString converts tier to string
func TierToString(tier DonorTier) string {
	switch tier {
	case TierBronze:
		return "Bronze 🥉"
	case TierSilver:
		return "Silver 🥈"
	case TierGold:
		return "Gold 🥇"
	case TierPlatinum:
		return "Platinum 💎"
	default:
		return "None"
	}
}
