// Motoko Donation Canister for Internet Computer (ICP)
// A secure donation system with donor tier tracking and admin controls

import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import ExperimentalCycles "mo:base/ExperimentalCycles";

actor DonationCanister {

  // Type definitions
  type DonorTier = {
    #None;
    #Bronze;
    #Silver;
    #Gold;
    #Platinum;
  };

  type DonationRecord = {
    donor: Principal;
    amount: Nat;
    total: Nat;
    tier: DonorTier;
    timestamp: Int;
  };

  type WithdrawalRecord = {
    admin: Principal;
    amount: Nat;
    recipient: Principal;
    timestamp: Int;
  };

  type DonorStats = {
    amount: Nat;
    tier: DonorTier;
    firstDonationTime: ?Int;
  };

  type ContractStats = {
    totalDonations: Nat;
    donorCount: Nat;
    paused: Bool;
    admin: Principal;
    balance: Nat;
  };

  // Error types
  type Error = {
    #AlreadyInitialized;
    #NotInitialized;
    #NotAdmin;
    #ContractPaused;
    #DonationTooSmall;
    #DonationTooLarge;
    #InvalidLimits;
    #InsufficientBalance;
    #TransferFailed;
  };

  // State variables
  private stable var admin: Principal = Principal.fromText("aaaaa-aa");
  private stable var totalDonations: Nat = 0;
  private stable var donorCount: Nat = 0;
  private stable var minDonation: Nat = 0;
  private stable var maxDonation: Nat = 0;
  private stable var paused: Bool = false;
  private stable var initialized: Bool = false;

  // Stable storage for upgrades
  private stable var donorAmountsEntries: [(Principal, Nat)] = [];
  private stable var donorFirstDonationEntries: [(Principal, Int)] = [];

  // HashMap for donor amounts
  private var donorAmounts = HashMap.HashMap<Principal, Nat>(
    10,
    Principal.equal,
    Principal.hash
  );

  // HashMap for first donation timestamps
  private var donorFirstDonation = HashMap.HashMap<Principal, Int>(
    10,
    Principal.equal,
    Principal.hash
  );

  // Constants
  private let ICP_DECIMALS: Nat = 100_000_000; // 1 ICP = 10^8 e8s
  private let TIER_BRONZE_MIN: Nat = ICP_DECIMALS / 100; // 0.01 ICP
  private let TIER_SILVER_MIN: Nat = ICP_DECIMALS / 10;  // 0.1 ICP
  private let TIER_GOLD_MIN: Nat = ICP_DECIMALS;         // 1 ICP
  private let TIER_PLATINUM_MIN: Nat = ICP_DECIMALS * 10; // 10 ICP

  // System functions for upgrades
  system func preupgrade() {
    donorAmountsEntries := Iter.toArray(donorAmounts.entries());
    donorFirstDonationEntries := Iter.toArray(donorFirstDonation.entries());
  };

  system func postupgrade() {
    donorAmounts := HashMap.fromIter<Principal, Nat>(
      donorAmountsEntries.vals(),
      10,
      Principal.equal,
      Principal.hash
    );
    donorFirstDonation := HashMap.fromIter<Principal, Int>(
      donorFirstDonationEntries.vals(),
      10,
      Principal.equal,
      Principal.hash
    );
    donorAmountsEntries := [];
    donorFirstDonationEntries := [];
  };

  // Private helper functions

  private func isAdmin(caller: Principal): Bool {
    Principal.equal(caller, admin)
  };

  private func calculateTier(amount: Nat): DonorTier {
    if (amount >= TIER_PLATINUM_MIN) {
      #Platinum
    } else if (amount >= TIER_GOLD_MIN) {
      #Gold
    } else if (amount >= TIER_SILVER_MIN) {
      #Silver
    } else if (amount >= TIER_BRONZE_MIN) {
      #Bronze
    } else {
      #None
    }
  };

  // Public functions

  public shared(msg) func initialize(
    newAdmin: Principal,
    min: Nat,
    max: Nat
  ): async Result.Result<Bool, Error> {
    if (initialized) {
      return #err(#AlreadyInitialized);
    };

    if (min == 0 or max <= min) {
      return #err(#InvalidLimits);
    };

    admin := newAdmin;
    minDonation := min;
    maxDonation := max;
    initialized := true;

    #ok(true)
  };

  public shared(msg) func donate(): async Result.Result<DonorTier, Error> {
    if (not initialized) {
      return #err(#NotInitialized);
    };

    if (paused) {
      return #err(#ContractPaused);
    };

    let donor = msg.caller;
    let amount = ExperimentalCycles.available();

    if (amount < minDonation) {
      return #err(#DonationTooSmall);
    };

    if (amount > maxDonation) {
      return #err(#DonationTooLarge);
    };

    // Accept the cycles
    let accepted = ExperimentalCycles.accept(amount);

    // Update donor amount
    let currentAmount = Option.get(donorAmounts.get(donor), 0);
    let newAmount = currentAmount + accepted;
    donorAmounts.put(donor, newAmount);

    // Update total donations
    totalDonations += accepted;

    // Record first donation time if needed
    switch (donorFirstDonation.get(donor)) {
      case null {
        donorFirstDonation.put(donor, Time.now());
        donorCount += 1;
      };
      case (?_) {};
    };

    // Calculate tier
    let tier = calculateTier(newAmount);

    #ok(tier)
  };

  public shared(msg) func withdraw(
    amount: Nat,
    recipient: Principal
  ): async Result.Result<Bool, Error> {
    if (not isAdmin(msg.caller)) {
      return #err(#NotAdmin);
    };

    if (not initialized) {
      return #err(#NotInitialized);
    };

    if (amount == 0) {
      return #err(#InvalidLimits);
    };

    let balance = ExperimentalCycles.balance();
    if (balance < amount) {
      return #err(#InsufficientBalance);
    };

    // Send cycles to recipient
    ExperimentalCycles.add(amount);
    // Note: In production, would use IC management canister for actual transfers

    #ok(true)
  };

  public shared(msg) func emergencyWithdraw(
    recipient: Principal
  ): async Result.Result<Nat, Error> {
    if (not isAdmin(msg.caller)) {
      return #err(#NotAdmin);
    };

    if (not initialized) {
      return #err(#NotInitialized);
    };

    let balance = ExperimentalCycles.balance();

    // Send all cycles to recipient
    ExperimentalCycles.add(balance);
    // Note: In production, would use IC management canister for actual transfers

    #ok(balance)
  };

  public shared(msg) func pause(): async Result.Result<Bool, Error> {
    if (not isAdmin(msg.caller)) {
      return #err(#NotAdmin);
    };

    if (paused) {
      return #err(#ContractPaused);
    };

    paused := true;
    #ok(true)
  };

  public shared(msg) func unpause(): async Result.Result<Bool, Error> {
    if (not isAdmin(msg.caller)) {
      return #err(#NotAdmin);
    };

    if (not paused) {
      return #err(#ContractPaused);
    };

    paused := false;
    #ok(true)
  };

  public shared(msg) func updateAdmin(newAdmin: Principal): async Result.Result<Bool, Error> {
    if (not isAdmin(msg.caller)) {
      return #err(#NotAdmin);
    };

    admin := newAdmin;
    #ok(true)
  };

  public shared(msg) func updateLimits(min: Nat, max: Nat): async Result.Result<Bool, Error> {
    if (not isAdmin(msg.caller)) {
      return #err(#NotAdmin);
    };

    if (min == 0 or max <= min) {
      return #err(#InvalidLimits);
    };

    minDonation := min;
    maxDonation := max;
    #ok(true)
  };

  // Query functions (read-only)

  public query func getTotalDonations(): async Nat {
    totalDonations
  };

  public query func getDonorAmount(donor: Principal): async Nat {
    Option.get(donorAmounts.get(donor), 0)
  };

  public query func getDonorTier(donor: Principal): async DonorTier {
    let amount = Option.get(donorAmounts.get(donor), 0);
    calculateTier(amount)
  };

  public query func getDonorCount(): async Nat {
    donorCount
  };

  public query func isPaused(): async Bool {
    paused
  };

  public query func getAdmin(): async Principal {
    admin
  };

  public query func getMinDonation(): async Nat {
    minDonation
  };

  public query func getMaxDonation(): async Nat {
    maxDonation
  };

  public query func isInitialized(): async Bool {
    initialized
  };

  public query func getBalance(): async Nat {
    ExperimentalCycles.balance()
  };

  public query func getDonorStats(donor: Principal): async DonorStats {
    let amount = Option.get(donorAmounts.get(donor), 0);
    {
      amount = amount;
      tier = calculateTier(amount);
      firstDonationTime = donorFirstDonation.get(donor);
    }
  };

  public query func getContractStats(): async ContractStats {
    {
      totalDonations = totalDonations;
      donorCount = donorCount;
      paused = paused;
      admin = admin;
      balance = ExperimentalCycles.balance();
    }
  };

  // Get all donors (for analytics)
  public query func getAllDonors(): async [(Principal, Nat)] {
    Iter.toArray(donorAmounts.entries())
  };

  // Utility functions

  public query func tierToText(tier: DonorTier): async Text {
    switch (tier) {
      case (#None) "None";
      case (#Bronze) "Bronze 🥉";
      case (#Silver) "Silver 🥈";
      case (#Gold) "Gold 🥇";
      case (#Platinum) "Platinum 💎";
    }
  };

  public query func formatAmount(amount: Nat): async Text {
    let icp = amount / ICP_DECIMALS;
    let e8s = amount % ICP_DECIMALS;
    Nat.toText(icp) # "." # Nat.toText(e8s) # " ICP"
  };
}
