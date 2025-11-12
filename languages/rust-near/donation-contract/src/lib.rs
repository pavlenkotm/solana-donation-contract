use near_sdk::borsh::{self, BorshDeserialize, BorshSerialize};
use near_sdk::collections::LookupMap;
use near_sdk::json_types::U128;
use near_sdk::serde::{Deserialize, Serialize};
use near_sdk::{env, near_bindgen, AccountId, Balance, PanicOnDefault, Promise};

/// Donation contract for NEAR Protocol
/// Features donor tier tracking and admin controls
#[near_bindgen]
#[derive(BorshDeserialize, BorshSerialize, PanicOnDefault)]
pub struct DonationContract {
    /// Contract administrator
    admin: AccountId,
    /// Total donations received in yoctoNEAR
    total_donations: Balance,
    /// Mapping of donor addresses to their total contributions
    donor_amounts: LookupMap<AccountId, Balance>,
    /// Number of unique donors
    donor_count: u64,
    /// Minimum donation amount in yoctoNEAR
    min_donation: Balance,
    /// Maximum donation amount in yoctoNEAR
    max_donation: Balance,
    /// Contract pause state
    paused: bool,
    /// Initialization flag
    initialized: bool,
}

/// Donor tier levels
#[derive(BorshDeserialize, BorshSerialize, Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]
#[serde(crate = "near_sdk::serde")]
pub enum DonorTier {
    None = 0,
    Bronze = 1,   // 0.01+ NEAR
    Silver = 2,   // 0.1+ NEAR
    Gold = 3,     // 1+ NEAR
    Platinum = 4, // 10+ NEAR
}

/// Donation event data
#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "near_sdk::serde")]
pub struct DonationEvent {
    donor: AccountId,
    amount: U128,
    total: U128,
    tier: DonorTier,
    timestamp: u64,
}

/// Donor statistics
#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "near_sdk::serde")]
pub struct DonorStats {
    amount: U128,
    tier: DonorTier,
}

/// Contract statistics
#[derive(Serialize, Deserialize, Debug)]
#[serde(crate = "near_sdk::serde")]
pub struct ContractStats {
    total_donations: U128,
    donor_count: u64,
    paused: bool,
    admin: AccountId,
    balance: U128,
}

const NEAR: Balance = 1_000_000_000_000_000_000_000_000; // 1 NEAR in yoctoNEAR (10^24)

#[near_bindgen]
impl DonationContract {
    /// Initialize a new donation contract
    #[init]
    pub fn new() -> Self {
        Self {
            admin: env::predecessor_account_id(),
            total_donations: 0,
            donor_amounts: LookupMap::new(b"d"),
            donor_count: 0,
            min_donation: 0,
            max_donation: 0,
            paused: false,
            initialized: false,
        }
    }

    /// Initialize the contract with admin and donation limits
    pub fn initialize(
        &mut self,
        admin: AccountId,
        min_donation: U128,
        max_donation: U128,
    ) {
        assert!(!self.initialized, "Already initialized");
        assert!(min_donation.0 > 0, "Minimum donation must be > 0");
        assert!(max_donation.0 > min_donation.0, "Max must be > min");

        self.admin = admin;
        self.min_donation = min_donation.0;
        self.max_donation = max_donation.0;
        self.initialized = true;

        env::log_str(&format!(
            "Initialized with admin: {}, min: {}, max: {}",
            self.admin, min_donation.0, max_donation.0
        ));
    }

    /// Accept a donation (payable function)
    #[payable]
    pub fn donate(&mut self) -> DonorTier {
        assert!(self.initialized, "Not initialized");
        assert!(!self.paused, "Contract is paused");

        let donor = env::predecessor_account_id();
        let amount = env::attached_deposit();

        assert!(amount >= self.min_donation, "Donation too small");
        assert!(amount <= self.max_donation, "Donation too large");

        // Update donor amount
        let current_amount = self.donor_amounts.get(&donor).unwrap_or(0);
        let new_amount = current_amount.checked_add(amount).expect("Overflow");

        self.donor_amounts.insert(&donor, &new_amount);

        // Update totals
        self.total_donations = self
            .total_donations
            .checked_add(amount)
            .expect("Overflow");

        // Increment donor count if first donation
        if current_amount == 0 {
            self.donor_count += 1;
        }

        // Calculate tier
        let tier = Self::calculate_tier(new_amount);

        // Log event
        env::log_str(&format!(
            "DonationReceived: {{ donor: {}, amount: {}, total: {}, tier: {:?}, timestamp: {} }}",
            donor,
            amount,
            new_amount,
            tier,
            env::block_timestamp()
        ));

        tier
    }

    /// Withdraw funds (admin only)
    pub fn withdraw(&mut self, amount: U128, recipient: AccountId) -> Promise {
        self.assert_admin();
        assert!(self.initialized, "Not initialized");
        assert!(amount.0 > 0, "Amount must be > 0");
        assert!(
            amount.0 <= env::account_balance(),
            "Insufficient balance"
        );

        env::log_str(&format!(
            "Withdrawal: {{ admin: {}, amount: {}, recipient: {}, timestamp: {} }}",
            env::predecessor_account_id(),
            amount.0,
            recipient,
            env::block_timestamp()
        ));

        Promise::new(recipient).transfer(amount.0)
    }

    /// Emergency withdrawal of all funds (admin only)
    pub fn emergency_withdraw(&mut self, recipient: AccountId) -> Promise {
        self.assert_admin();
        assert!(self.initialized, "Not initialized");

        let balance = env::account_balance();

        env::log_str(&format!(
            "EmergencyWithdrawal: {{ admin: {}, amount: {}, recipient: {}, timestamp: {} }}",
            env::predecessor_account_id(),
            balance,
            recipient,
            env::block_timestamp()
        ));

        Promise::new(recipient).transfer(balance)
    }

    /// Pause the contract (admin only)
    pub fn pause(&mut self) {
        self.assert_admin();
        assert!(!self.paused, "Already paused");

        self.paused = true;

        env::log_str(&format!(
            "ContractPaused: {{ admin: {}, timestamp: {} }}",
            env::predecessor_account_id(),
            env::block_timestamp()
        ));
    }

    /// Unpause the contract (admin only)
    pub fn unpause(&mut self) {
        self.assert_admin();
        assert!(self.paused, "Not paused");

        self.paused = false;

        env::log_str(&format!(
            "ContractUnpaused: {{ admin: {}, timestamp: {} }}",
            env::predecessor_account_id(),
            env::block_timestamp()
        ));
    }

    /// Update admin (admin only)
    pub fn update_admin(&mut self, new_admin: AccountId) {
        self.assert_admin();
        self.admin = new_admin;
    }

    /// Update donation limits (admin only)
    pub fn update_limits(&mut self, min_donation: U128, max_donation: U128) {
        self.assert_admin();
        assert!(min_donation.0 > 0, "Min must be > 0");
        assert!(max_donation.0 > min_donation.0, "Max must be > min");

        self.min_donation = min_donation.0;
        self.max_donation = max_donation.0;
    }

    // View functions

    /// Get total donations
    pub fn get_total_donations(&self) -> U128 {
        U128(self.total_donations)
    }

    /// Get donor's total contribution
    pub fn get_donor_amount(&self, donor: AccountId) -> U128 {
        U128(self.donor_amounts.get(&donor).unwrap_or(0))
    }

    /// Get donor's tier
    pub fn get_donor_tier(&self, donor: AccountId) -> DonorTier {
        let amount = self.donor_amounts.get(&donor).unwrap_or(0);
        Self::calculate_tier(amount)
    }

    /// Get number of unique donors
    pub fn get_donor_count(&self) -> u64 {
        self.donor_count
    }

    /// Check if contract is paused
    pub fn is_paused(&self) -> bool {
        self.paused
    }

    /// Get admin address
    pub fn get_admin(&self) -> AccountId {
        self.admin.clone()
    }

    /// Get contract balance
    pub fn get_balance(&self) -> U128 {
        U128(env::account_balance())
    }

    /// Get minimum donation
    pub fn get_min_donation(&self) -> U128 {
        U128(self.min_donation)
    }

    /// Get maximum donation
    pub fn get_max_donation(&self) -> U128 {
        U128(self.max_donation)
    }

    /// Get comprehensive donor stats
    pub fn get_donor_stats(&self, donor: AccountId) -> DonorStats {
        let amount = self.donor_amounts.get(&donor).unwrap_or(0);
        DonorStats {
            amount: U128(amount),
            tier: Self::calculate_tier(amount),
        }
    }

    /// Get contract stats
    pub fn get_contract_stats(&self) -> ContractStats {
        ContractStats {
            total_donations: U128(self.total_donations),
            donor_count: self.donor_count,
            paused: self.paused,
            admin: self.admin.clone(),
            balance: U128(env::account_balance()),
        }
    }

    // Private helper functions

    /// Assert caller is admin
    fn assert_admin(&self) {
        assert_eq!(
            env::predecessor_account_id(),
            self.admin,
            "Only admin can call this function"
        );
    }

    /// Calculate donor tier based on total contribution
    fn calculate_tier(amount: Balance) -> DonorTier {
        if amount >= 10 * NEAR {
            DonorTier::Platinum
        } else if amount >= NEAR {
            DonorTier::Gold
        } else if amount >= NEAR / 10 {
            DonorTier::Silver
        } else if amount >= NEAR / 100 {
            DonorTier::Bronze
        } else {
            DonorTier::None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use near_sdk::test_utils::{accounts, VMContextBuilder};
    use near_sdk::{testing_env, VMContext};

    fn get_context(predecessor: AccountId) -> VMContext {
        VMContextBuilder::new()
            .predecessor_account_id(predecessor)
            .build()
    }

    #[test]
    fn test_initialization() {
        let context = get_context(accounts(0));
        testing_env!(context);

        let mut contract = DonationContract::new();
        contract.initialize(
            accounts(0),
            U128(10_000_000_000_000_000_000_000),
            U128(100_000_000_000_000_000_000_000_000),
        );

        assert_eq!(contract.get_admin(), accounts(0));
        assert!(contract.initialized);
    }

    #[test]
    fn test_tier_calculation() {
        assert_eq!(DonationContract::calculate_tier(0), DonorTier::None);
        assert_eq!(
            DonationContract::calculate_tier(NEAR / 100),
            DonorTier::Bronze
        );
        assert_eq!(
            DonationContract::calculate_tier(NEAR / 10),
            DonorTier::Silver
        );
        assert_eq!(DonationContract::calculate_tier(NEAR), DonorTier::Gold);
        assert_eq!(
            DonationContract::calculate_tier(10 * NEAR),
            DonorTier::Platinum
        );
    }

    #[test]
    #[should_panic(expected = "Already initialized")]
    fn test_double_initialization() {
        let context = get_context(accounts(0));
        testing_env!(context);

        let mut contract = DonationContract::new();
        contract.initialize(accounts(0), U128(1), U128(100));
        contract.initialize(accounts(0), U128(1), U128(100)); // Should panic
    }
}
