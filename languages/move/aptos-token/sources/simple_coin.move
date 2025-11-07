module simple_coin::coin {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability, FreezeCapability};
    use aptos_framework::account;

    /// Error codes
    const E_NOT_OWNER: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_INSUFFICIENT_BALANCE: u64 = 3;

    /// Coin type for SimpleCoin
    struct SimpleCoin {}

    /// Capabilities stored under coin owner's account
    struct Capabilities has key {
        mint_cap: MintCapability<SimpleCoin>,
        burn_cap: BurnCapability<SimpleCoin>,
        freeze_cap: FreezeCapability<SimpleCoin>,
    }

    /// Coin metadata
    struct CoinInfo has key {
        name: String,
        symbol: String,
        decimals: u8,
        total_supply: u64,
    }

    /// Initialize the coin module
    /// Can only be called once by the module publisher
    public entry fun initialize(
        account: &signer,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        monitor_supply: bool,
    ) {
        let account_addr = signer::address_of(account);

        // Ensure not already initialized
        assert!(!exists<Capabilities>(account_addr), E_ALREADY_INITIALIZED);

        // Initialize the coin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<SimpleCoin>(
            account,
            string::utf8(name),
            string::utf8(symbol),
            decimals,
            monitor_supply,
        );

        // Store capabilities
        move_to(account, Capabilities {
            mint_cap,
            burn_cap,
            freeze_cap,
        });

        // Store coin info
        move_to(account, CoinInfo {
            name: string::utf8(name),
            symbol: string::utf8(symbol),
            decimals,
            total_supply: 0,
        });
    }

    /// Mint new coins to a recipient
    /// Only the coin owner can mint
    public entry fun mint(
        owner: &signer,
        recipient: address,
        amount: u64,
    ) acquires Capabilities, CoinInfo {
        let owner_addr = signer::address_of(owner);

        // Verify owner
        assert!(exists<Capabilities>(owner_addr), E_NOT_OWNER);

        // Get mint capability
        let caps = borrow_global<Capabilities>(owner_addr);

        // Mint coins
        let coins = coin::mint<SimpleCoin>(amount, &caps.mint_cap);

        // Register recipient if needed
        if (!coin::is_account_registered<SimpleCoin>(recipient)) {
            coin::register<SimpleCoin>(owner);
        };

        // Deposit to recipient
        coin::deposit(recipient, coins);

        // Update total supply
        let coin_info = borrow_global_mut<CoinInfo>(owner_addr);
        coin_info.total_supply = coin_info.total_supply + amount;
    }

    /// Burn coins from the signer's account
    public entry fun burn(
        account: &signer,
        amount: u64,
    ) acquires Capabilities, CoinInfo {
        let account_addr = signer::address_of(account);

        // Withdraw coins from account
        let coins = coin::withdraw<SimpleCoin>(account, amount);

        // Get owner's capabilities
        let caps = borrow_global<Capabilities>(@simple_coin);

        // Burn coins
        coin::burn(coins, &caps.burn_cap);

        // Update total supply
        let coin_info = borrow_global_mut<CoinInfo>(@simple_coin);
        coin_info.total_supply = coin_info.total_supply - amount;
    }

    /// Transfer coins from sender to recipient
    public entry fun transfer(
        from: &signer,
        to: address,
        amount: u64,
    ) {
        coin::transfer<SimpleCoin>(from, to, amount);
    }

    /// Register an account to receive SimpleCoin
    public entry fun register(account: &signer) {
        coin::register<SimpleCoin>(account);
    }

    /// Get balance of an account
    #[view]
    public fun balance_of(account: address): u64 {
        coin::balance<SimpleCoin>(account)
    }

    /// Get coin name
    #[view]
    public fun name(): String acquires CoinInfo {
        borrow_global<CoinInfo>(@simple_coin).name
    }

    /// Get coin symbol
    #[view]
    public fun symbol(): String acquires CoinInfo {
        borrow_global<CoinInfo>(@simple_coin).symbol
    }

    /// Get decimals
    #[view]
    public fun decimals(): u8 acquires CoinInfo {
        borrow_global<CoinInfo>(@simple_coin).decimals
    }

    /// Get total supply
    #[view]
    public fun total_supply(): u64 acquires CoinInfo {
        borrow_global<CoinInfo>(@simple_coin).total_supply
    }

    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test(owner = @simple_coin)]
    public fun test_initialize(owner: &signer) {
        create_account_for_test(signer::address_of(owner));

        initialize(
            owner,
            b"SimpleCoin",
            b"SIMP",
            8,
            true,
        );

        assert!(name() == string::utf8(b"SimpleCoin"), 1);
        assert!(symbol() == string::utf8(b"SIMP"), 2);
        assert!(decimals() == 8, 3);
    }

    #[test(owner = @simple_coin, user = @0x123)]
    public fun test_mint(owner: &signer, user: &signer) acquires Capabilities, CoinInfo {
        create_account_for_test(signer::address_of(owner));
        create_account_for_test(signer::address_of(user));

        initialize(owner, b"SimpleCoin", b"SIMP", 8, true);

        let user_addr = signer::address_of(user);
        coin::register<SimpleCoin>(user);

        mint(owner, user_addr, 1000);

        assert!(balance_of(user_addr) == 1000, 4);
        assert!(total_supply() == 1000, 5);
    }

    #[test(owner = @simple_coin, user = @0x123)]
    public fun test_transfer(owner: &signer, user: &signer) acquires Capabilities, CoinInfo {
        create_account_for_test(signer::address_of(owner));
        create_account_for_test(signer::address_of(user));

        initialize(owner, b"SimpleCoin", b"SIMP", 8, true);

        let owner_addr = signer::address_of(owner);
        let user_addr = signer::address_of(user);

        coin::register<SimpleCoin>(owner);
        coin::register<SimpleCoin>(user);

        mint(owner, owner_addr, 1000);
        transfer(owner, user_addr, 500);

        assert!(balance_of(owner_addr) == 500, 6);
        assert!(balance_of(user_addr) == 500, 7);
    }

    #[test(owner = @simple_coin, user = @0x123)]
    public fun test_burn(owner: &signer, user: &signer) acquires Capabilities, CoinInfo {
        create_account_for_test(signer::address_of(owner));
        create_account_for_test(signer::address_of(user));

        initialize(owner, b"SimpleCoin", b"SIMP", 8, true);

        let user_addr = signer::address_of(user);
        coin::register<SimpleCoin>(user);

        mint(owner, user_addr, 1000);
        burn(user, 300);

        assert!(balance_of(user_addr) == 700, 8);
        assert!(total_supply() == 700, 9);
    }
}
