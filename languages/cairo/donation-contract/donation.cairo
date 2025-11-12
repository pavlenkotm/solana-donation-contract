// Cairo Donation Contract for StarkNet
// A secure donation system with donor tier tracking

use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_contract_address;

#[starknet::interface]
trait IDonationContract<TContractState> {
    fn initialize(ref self: TContractState, admin: ContractAddress, min_donation: u128, max_donation: u128);
    fn donate(ref self: TContractState) -> bool;
    fn withdraw(ref self: TContractState, amount: u128, recipient: ContractAddress) -> bool;
    fn emergency_withdraw(ref self: TContractState, recipient: ContractAddress) -> bool;
    fn pause(ref self: TContractState) -> bool;
    fn unpause(ref self: TContractState) -> bool;

    // View functions
    fn get_total_donations(self: @TContractState) -> u128;
    fn get_donor_amount(self: @TContractState, donor: ContractAddress) -> u128;
    fn get_donor_tier(self: @TContractState, donor: ContractAddress) -> u8;
    fn is_paused(self: @TContractState) -> bool;
    fn get_admin(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod DonationContract {
    use super::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::contract_address_const;
    use starknet::info::get_block_timestamp;

    #[storage]
    struct Storage {
        admin: ContractAddress,
        total_donations: u128,
        donor_amounts: LegacyMap<ContractAddress, u128>,
        donor_count: u32,
        min_donation: u128,
        max_donation: u128,
        paused: bool,
        initialized: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DonationReceived: DonationReceived,
        Withdrawal: Withdrawal,
        EmergencyWithdrawal: EmergencyWithdrawal,
        ContractPaused: ContractPaused,
        ContractUnpaused: ContractUnpaused,
        Initialized: Initialized,
    }

    #[derive(Drop, starknet::Event)]
    struct DonationReceived {
        donor: ContractAddress,
        amount: u128,
        total: u128,
        tier: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdrawal {
        admin: ContractAddress,
        amount: u128,
        recipient: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyWithdrawal {
        admin: ContractAddress,
        amount: u128,
        recipient: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ContractPaused {
        admin: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ContractUnpaused {
        admin: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Initialized {
        admin: ContractAddress,
        min_donation: u128,
        max_donation: u128,
    }

    // Donor tiers based on contribution
    const TIER_BRONZE: u8 = 1;  // 0.01+ ETH
    const TIER_SILVER: u8 = 2;  // 0.1+ ETH
    const TIER_GOLD: u8 = 3;    // 1+ ETH
    const TIER_PLATINUM: u8 = 4; // 10+ ETH

    const ETH_DECIMALS: u128 = 1000000000000000000; // 10^18

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Contract starts uninitialized
        self.initialized.write(false);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl DonationContractImpl of super::IDonationContract<ContractState> {
        fn initialize(
            ref self: ContractState,
            admin: ContractAddress,
            min_donation: u128,
            max_donation: u128
        ) {
            assert(!self.initialized.read(), 'Already initialized');
            assert(min_donation > 0, 'Min donation must be > 0');
            assert(max_donation > min_donation, 'Max must be > min');

            self.admin.write(admin);
            self.min_donation.write(min_donation);
            self.max_donation.write(max_donation);
            self.total_donations.write(0);
            self.donor_count.write(0);
            self.initialized.write(true);
            self.paused.write(false);

            self.emit(Initialized {
                admin,
                min_donation,
                max_donation,
            });
        }

        fn donate(ref self: ContractState) -> bool {
            assert(self.initialized.read(), 'Not initialized');
            assert(!self.paused.read(), 'Contract is paused');

            let caller = get_caller_address();
            let contract = get_contract_address();

            // In real implementation, would use get_tx_info().amount for ETH sent
            // For demonstration, we'll use a placeholder
            let amount: u128 = 100000000000000000; // 0.1 ETH placeholder

            assert(amount >= self.min_donation.read(), 'Donation too small');
            assert(amount <= self.max_donation.read(), 'Donation too large');

            // Update donor amount
            let current_amount = self.donor_amounts.read(caller);
            let new_amount = current_amount + amount;
            self.donor_amounts.write(caller, new_amount);

            // Update totals
            let total = self.total_donations.read() + amount;
            self.total_donations.write(total);

            // Increment donor count if first donation
            if current_amount == 0 {
                let count = self.donor_count.read() + 1;
                self.donor_count.write(count);
            }

            // Calculate tier
            let tier = self.calculate_tier(new_amount);

            self.emit(DonationReceived {
                donor: caller,
                amount,
                total: new_amount,
                tier,
                timestamp: get_block_timestamp(),
            });

            true
        }

        fn withdraw(
            ref self: ContractState,
            amount: u128,
            recipient: ContractAddress
        ) -> bool {
            self.only_admin();
            assert(self.initialized.read(), 'Not initialized');
            assert(amount > 0, 'Amount must be > 0');

            // In real implementation, would transfer ETH here

            self.emit(Withdrawal {
                admin: get_caller_address(),
                amount,
                recipient,
                timestamp: get_block_timestamp(),
            });

            true
        }

        fn emergency_withdraw(
            ref self: ContractState,
            recipient: ContractAddress
        ) -> bool {
            self.only_admin();
            assert(self.initialized.read(), 'Not initialized');

            let total = self.total_donations.read();

            // In real implementation, would transfer all ETH here

            self.emit(EmergencyWithdrawal {
                admin: get_caller_address(),
                amount: total,
                recipient,
                timestamp: get_block_timestamp(),
            });

            true
        }

        fn pause(ref self: ContractState) -> bool {
            self.only_admin();
            assert(!self.paused.read(), 'Already paused');

            self.paused.write(true);

            self.emit(ContractPaused {
                admin: get_caller_address(),
                timestamp: get_block_timestamp(),
            });

            true
        }

        fn unpause(ref self: ContractState) -> bool {
            self.only_admin();
            assert(self.paused.read(), 'Not paused');

            self.paused.write(false);

            self.emit(ContractUnpaused {
                admin: get_caller_address(),
                timestamp: get_block_timestamp(),
            });

            true
        }

        // View functions
        fn get_total_donations(self: @ContractState) -> u128 {
            self.total_donations.read()
        }

        fn get_donor_amount(self: @ContractState, donor: ContractAddress) -> u128 {
            self.donor_amounts.read(donor)
        }

        fn get_donor_tier(self: @ContractState, donor: ContractAddress) -> u8 {
            let amount = self.donor_amounts.read(donor);
            self.calculate_tier(amount)
        }

        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn only_admin(self: @ContractState) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Only admin');
        }

        fn calculate_tier(self: @ContractState, amount: u128) -> u8 {
            if amount >= 10 * ETH_DECIMALS {
                TIER_PLATINUM
            } else if amount >= ETH_DECIMALS {
                TIER_GOLD
            } else if amount >= ETH_DECIMALS / 10 {
                TIER_SILVER
            } else if amount >= ETH_DECIMALS / 100 {
                TIER_BRONZE
            } else {
                0
            }
        }
    }
}
