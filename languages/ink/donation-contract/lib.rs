#![cfg_attr(not(feature = "std"), no_std, no_main)]

/// Ink! Donation Contract for Polkadot/Substrate
/// A secure donation system with donor tier tracking and admin controls
#[ink::contract]
mod donation_contract {
    use ink::storage::Mapping;

    /// Donation contract storage
    #[ink(storage)]
    pub struct DonationContract {
        /// Contract administrator
        admin: AccountId,
        /// Total donations received
        total_donations: Balance,
        /// Mapping of donor addresses to their total contributions
        donor_amounts: Mapping<AccountId, Balance>,
        /// Number of unique donors
        donor_count: u32,
        /// Minimum donation amount
        min_donation: Balance,
        /// Maximum donation amount
        max_donation: Balance,
        /// Contract pause state
        paused: bool,
        /// Initialization flag
        initialized: bool,
    }

    /// Donor tier levels
    #[derive(Debug, PartialEq, Eq, scale::Encode, scale::Decode)]
    #[cfg_attr(feature = "std", derive(scale_info::TypeInfo))]
    pub enum DonorTier {
        None = 0,
        Bronze = 1,   // 0.01+ DOT
        Silver = 2,   // 0.1+ DOT
        Gold = 3,     // 1+ DOT
        Platinum = 4, // 10+ DOT
    }

    /// Events emitted by the contract
    #[ink(event)]
    pub struct DonationReceived {
        #[ink(topic)]
        donor: AccountId,
        amount: Balance,
        total: Balance,
        tier: u8,
        timestamp: Timestamp,
    }

    #[ink(event)]
    pub struct Withdrawal {
        #[ink(topic)]
        admin: AccountId,
        amount: Balance,
        recipient: AccountId,
        timestamp: Timestamp,
    }

    #[ink(event)]
    pub struct EmergencyWithdrawal {
        #[ink(topic)]
        admin: AccountId,
        amount: Balance,
        recipient: AccountId,
        timestamp: Timestamp,
    }

    #[ink(event)]
    pub struct ContractPaused {
        #[ink(topic)]
        admin: AccountId,
        timestamp: Timestamp,
    }

    #[ink(event)]
    pub struct ContractUnpaused {
        #[ink(topic)]
        admin: AccountId,
        timestamp: Timestamp,
    }

    #[ink(event)]
    pub struct Initialized {
        admin: AccountId,
        min_donation: Balance,
        max_donation: Balance,
    }

    /// Error types
    #[derive(Debug, PartialEq, Eq, scale::Encode, scale::Decode)]
    #[cfg_attr(feature = "std", derive(scale_info::TypeInfo))]
    pub enum Error {
        /// Contract already initialized
        AlreadyInitialized,
        /// Contract not initialized
        NotInitialized,
        /// Caller is not admin
        NotAdmin,
        /// Contract is paused
        ContractPaused,
        /// Contract is not paused
        ContractNotPaused,
        /// Donation amount too small
        DonationTooSmall,
        /// Donation amount too large
        DonationTooLarge,
        /// Invalid donation limits
        InvalidLimits,
        /// Insufficient contract balance
        InsufficientBalance,
        /// Transfer failed
        TransferFailed,
    }

    pub type Result<T> = core::result::Result<T, Error>;

    impl DonationContract {
        /// Creates a new donation contract (uninitialized)
        #[ink(constructor)]
        pub fn new() -> Self {
            Self {
                admin: AccountId::from([0x0; 32]),
                total_donations: 0,
                donor_amounts: Mapping::default(),
                donor_count: 0,
                min_donation: 0,
                max_donation: 0,
                paused: false,
                initialized: false,
            }
        }

        /// Initialize the contract with admin and donation limits
        #[ink(message)]
        pub fn initialize(
            &mut self,
            admin: AccountId,
            min_donation: Balance,
            max_donation: Balance,
        ) -> Result<()> {
            if self.initialized {
                return Err(Error::AlreadyInitialized);
            }

            if min_donation == 0 || max_donation <= min_donation {
                return Err(Error::InvalidLimits);
            }

            self.admin = admin;
            self.min_donation = min_donation;
            self.max_donation = max_donation;
            self.initialized = true;

            self.env().emit_event(Initialized {
                admin,
                min_donation,
                max_donation,
            });

            Ok(())
        }

        /// Accept a donation (payable function)
        #[ink(message, payable)]
        pub fn donate(&mut self) -> Result<()> {
            if !self.initialized {
                return Err(Error::NotInitialized);
            }

            if self.paused {
                return Err(Error::ContractPaused);
            }

            let caller = self.env().caller();
            let amount = self.env().transferred_value();

            if amount < self.min_donation {
                return Err(Error::DonationTooSmall);
            }

            if amount > self.max_donation {
                return Err(Error::DonationTooLarge);
            }

            // Update donor amount
            let current_amount = self.donor_amounts.get(&caller).unwrap_or(0);
            let new_amount = current_amount.saturating_add(amount);
            self.donor_amounts.insert(caller, &new_amount);

            // Update totals
            self.total_donations = self.total_donations.saturating_add(amount);

            // Increment donor count if first donation
            if current_amount == 0 {
                self.donor_count = self.donor_count.saturating_add(1);
            }

            // Calculate tier
            let tier = Self::calculate_tier_value(new_amount);

            self.env().emit_event(DonationReceived {
                donor: caller,
                amount,
                total: new_amount,
                tier,
                timestamp: self.env().block_timestamp(),
            });

            Ok(())
        }

        /// Withdraw funds (admin only)
        #[ink(message)]
        pub fn withdraw(&mut self, amount: Balance, recipient: AccountId) -> Result<()> {
            self.only_admin()?;

            if !self.initialized {
                return Err(Error::NotInitialized);
            }

            if self.env().balance() < amount {
                return Err(Error::InsufficientBalance);
            }

            if self.env().transfer(recipient, amount).is_err() {
                return Err(Error::TransferFailed);
            }

            self.env().emit_event(Withdrawal {
                admin: self.env().caller(),
                amount,
                recipient,
                timestamp: self.env().block_timestamp(),
            });

            Ok(())
        }

        /// Emergency withdrawal of all funds (admin only)
        #[ink(message)]
        pub fn emergency_withdraw(&mut self, recipient: AccountId) -> Result<()> {
            self.only_admin()?;

            if !self.initialized {
                return Err(Error::NotInitialized);
            }

            let balance = self.env().balance();

            if self.env().transfer(recipient, balance).is_err() {
                return Err(Error::TransferFailed);
            }

            self.env().emit_event(EmergencyWithdrawal {
                admin: self.env().caller(),
                amount: balance,
                recipient,
                timestamp: self.env().block_timestamp(),
            });

            Ok(())
        }

        /// Pause the contract (admin only)
        #[ink(message)]
        pub fn pause(&mut self) -> Result<()> {
            self.only_admin()?;

            if self.paused {
                return Err(Error::ContractPaused);
            }

            self.paused = true;

            self.env().emit_event(ContractPaused {
                admin: self.env().caller(),
                timestamp: self.env().block_timestamp(),
            });

            Ok(())
        }

        /// Unpause the contract (admin only)
        #[ink(message)]
        pub fn unpause(&mut self) -> Result<()> {
            self.only_admin()?;

            if !self.paused {
                return Err(Error::ContractNotPaused);
            }

            self.paused = false;

            self.env().emit_event(ContractUnpaused {
                admin: self.env().caller(),
                timestamp: self.env().block_timestamp(),
            });

            Ok(())
        }

        /// Get total donations
        #[ink(message)]
        pub fn get_total_donations(&self) -> Balance {
            self.total_donations
        }

        /// Get donor's total contribution
        #[ink(message)]
        pub fn get_donor_amount(&self, donor: AccountId) -> Balance {
            self.donor_amounts.get(&donor).unwrap_or(0)
        }

        /// Get donor's tier
        #[ink(message)]
        pub fn get_donor_tier(&self, donor: AccountId) -> u8 {
            let amount = self.donor_amounts.get(&donor).unwrap_or(0);
            Self::calculate_tier_value(amount)
        }

        /// Get number of unique donors
        #[ink(message)]
        pub fn get_donor_count(&self) -> u32 {
            self.donor_count
        }

        /// Check if contract is paused
        #[ink(message)]
        pub fn is_paused(&self) -> bool {
            self.paused
        }

        /// Get admin address
        #[ink(message)]
        pub fn get_admin(&self) -> AccountId {
            self.admin
        }

        /// Get contract balance
        #[ink(message)]
        pub fn get_balance(&self) -> Balance {
            self.env().balance()
        }

        // Internal functions

        /// Check if caller is admin
        fn only_admin(&self) -> Result<()> {
            if self.env().caller() != self.admin {
                return Err(Error::NotAdmin);
            }
            Ok(())
        }

        /// Calculate donor tier based on total contribution
        fn calculate_tier_value(amount: Balance) -> u8 {
            const DOT: Balance = 10_000_000_000; // 1 DOT = 10^10 Planck

            if amount >= 10 * DOT {
                4 // Platinum
            } else if amount >= DOT {
                3 // Gold
            } else if amount >= DOT / 10 {
                2 // Silver
            } else if amount >= DOT / 100 {
                1 // Bronze
            } else {
                0 // None
            }
        }
    }

    /// Unit tests
    #[cfg(test)]
    mod tests {
        use super::*;

        #[ink::test]
        fn test_initialization() {
            let mut contract = DonationContract::new();
            let admin = AccountId::from([0x1; 32]);

            assert_eq!(
                contract.initialize(admin, 1_000_000_000, 100_000_000_000),
                Ok(())
            );
            assert_eq!(contract.get_admin(), admin);
        }

        #[ink::test]
        fn test_donation() {
            let mut contract = DonationContract::new();
            let admin = AccountId::from([0x1; 32]);

            contract
                .initialize(admin, 1_000_000_000, 100_000_000_000)
                .unwrap();

            // Test donation functionality
            // Note: In real tests, would use ink_e2e for full integration testing
        }

        #[ink::test]
        fn test_tier_calculation() {
            const DOT: Balance = 10_000_000_000;

            assert_eq!(DonationContract::calculate_tier_value(0), 0);
            assert_eq!(DonationContract::calculate_tier_value(DOT / 100), 1); // Bronze
            assert_eq!(DonationContract::calculate_tier_value(DOT / 10), 2); // Silver
            assert_eq!(DonationContract::calculate_tier_value(DOT), 3); // Gold
            assert_eq!(DonationContract::calculate_tier_value(10 * DOT), 4); // Platinum
        }
    }
}
