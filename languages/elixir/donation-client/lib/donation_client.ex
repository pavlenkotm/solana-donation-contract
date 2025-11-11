defmodule DonationClient do
  @moduledoc """
  Elixir client for Solana Donation Contract.

  This module provides a concurrent, fault-tolerant interface for
  interacting with the Solana donation smart contract using OTP
  abstractions and pattern matching.

  ## Features
  - GenServer-based state management
  - Asynchronous RPC calls
  - Pattern matching for error handling
  - Supervision tree for fault tolerance
  - Real-time event streaming

  ## Example
      {:ok, pid} = DonationClient.start_link()
      {:ok, result} = DonationClient.donate(donor_pubkey, 0.5)
  """

  use GenServer
  require Logger

  alias DonationClient.{RPC, Transaction, Schemas}

  # =============================================================================
  # Constants
  # =============================================================================

  @lamports_per_sol 1_000_000_000
  @min_donation 1_000_000  # 0.001 SOL
  @max_donation 100_000_000_000  # 100 SOL

  @tier_bronze 1_000_000
  @tier_silver 100_000_000
  @tier_gold 1_000_000_000
  @tier_platinum 10_000_000_000

  # =============================================================================
  # Types
  # =============================================================================

  @type pubkey :: String.t()
  @type lamports :: non_neg_integer()
  @type sol :: float()
  @type donor_tier :: :bronze | :silver | :gold | :platinum

  @typedoc "Donation result"
  @type donation_result :: %{
    signature: String.t(),
    amount: lamports(),
    donor: pubkey(),
    new_tier: donor_tier(),
    total_donated: lamports()
  }

  @typedoc "Vault statistics"
  @type vault_stats :: %{
    admin: pubkey(),
    total_donated: lamports(),
    total_withdrawn: lamports(),
    current_balance: lamports(),
    donation_count: non_neg_integer(),
    unique_donors: non_neg_integer(),
    is_paused: boolean(),
    min_donation_amount: lamports(),
    max_donation_amount: lamports()
  }

  @typedoc "Donor information"
  @type donor_info :: %{
    donor: pubkey(),
    total_donated: lamports(),
    donation_count: non_neg_integer(),
    last_donation_timestamp: integer(),
    tier: donor_tier()
  }

  # =============================================================================
  # Client API
  # =============================================================================

  @doc """
  Starts the DonationClient GenServer.

  ## Options
  - `:rpc_url` - Solana RPC endpoint URL (default: devnet)
  - `:program_id` - The donation program ID

  ## Examples
      {:ok, pid} = DonationClient.start_link()
      {:ok, pid} = DonationClient.start_link(rpc_url: "https://api.mainnet-beta.solana.com")
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Make a donation to the vault.

  ## Parameters
  - `donor` - Donor's public key
  - `amount` - Amount in SOL (float)

  ## Returns
  - `{:ok, donation_result()}` on success
  - `{:error, reason}` on failure

  ## Examples
      {:ok, result} = DonationClient.donate("5FHn...", 0.5)
      # => {:ok, %{signature: "3Xy...", amount: 500_000_000, ...}}

      {:error, :donation_too_small} = DonationClient.donate("5FHn...", 0.0001)
  """
  @spec donate(pubkey(), sol()) :: {:ok, donation_result()} | {:error, atom()}
  def donate(donor, amount_sol) do
    GenServer.call(__MODULE__, {:donate, donor, amount_sol})
  end

  @doc """
  Get vault statistics.

  ## Returns
  - `{:ok, vault_stats()}` on success
  - `{:error, reason}` on failure

  ## Examples
      {:ok, stats} = DonationClient.get_vault_stats()
      IO.inspect(stats.total_donated)
  """
  @spec get_vault_stats() :: {:ok, vault_stats()} | {:error, atom()}
  def get_vault_stats do
    GenServer.call(__MODULE__, :get_vault_stats)
  end

  @doc """
  Get donor information.

  ## Parameters
  - `donor` - Donor's public key

  ## Returns
  - `{:ok, donor_info()}` on success
  - `{:error, reason}` on failure

  ## Examples
      case DonationClient.get_donor_info("5FHn...") do
        {:ok, %{tier: :platinum}} -> IO.puts("Platinum tier!")
        {:ok, info} -> IO.puts("Tier: \#{info.tier}")
        {:error, :not_found} -> IO.puts("Donor not found")
      end
  """
  @spec get_donor_info(pubkey()) :: {:ok, donor_info()} | {:error, atom()}
  def get_donor_info(donor) do
    GenServer.call(__MODULE__, {:get_donor_info, donor})
  end

  @doc """
  Withdraw funds from the vault (admin only).

  ## Parameters
  - `admin` - Admin's public key
  - `amount` - Amount in SOL (float)

  ## Returns
  - `{:ok, signature}` on success
  - `{:error, reason}` on failure
  """
  @spec withdraw(pubkey(), sol()) :: {:ok, String.t()} | {:error, atom()}
  def withdraw(admin, amount_sol) do
    GenServer.call(__MODULE__, {:withdraw, admin, amount_sol})
  end

  @doc """
  Subscribe to donation events.

  ## Examples
      DonationClient.subscribe_to_events(self())

      # In your process:
      receive do
        {:donation_event, event} ->
          IO.puts("New donation: \#{event.amount} lamports")
      end
  """
  @spec subscribe_to_events(pid()) :: :ok
  def subscribe_to_events(pid) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  # =============================================================================
  # Utility Functions
  # =============================================================================

  @doc """
  Convert SOL to lamports.

  ## Examples
      iex> DonationClient.sol_to_lamports(1.0)
      1_000_000_000

      iex> DonationClient.sol_to_lamports(0.001)
      1_000_000
  """
  @spec sol_to_lamports(sol()) :: lamports()
  def sol_to_lamports(sol) do
    round(sol * @lamports_per_sol)
  end

  @doc """
  Convert lamports to SOL.

  ## Examples
      iex> DonationClient.lamports_to_sol(1_000_000_000)
      1.0

      iex> DonationClient.lamports_to_sol(100_000_000)
      0.1
  """
  @spec lamports_to_sol(lamports()) :: sol()
  def lamports_to_sol(lamports) do
    lamports / @lamports_per_sol
  end

  @doc """
  Calculate donor tier based on total donations.

  ## Examples
      iex> DonationClient.calculate_tier(1_000_000)
      :bronze

      iex> DonationClient.calculate_tier(10_000_000_000)
      :platinum
  """
  @spec calculate_tier(lamports()) :: donor_tier()
  def calculate_tier(total_donated) do
    cond do
      total_donated >= @tier_platinum -> :platinum
      total_donated >= @tier_gold -> :gold
      total_donated >= @tier_silver -> :silver
      true -> :bronze
    end
  end

  @doc """
  Get tier emoji representation.

  ## Examples
      iex> DonationClient.tier_emoji(:platinum)
      "💎"

      iex> DonationClient.tier_emoji(:bronze)
      "🥉"
  """
  @spec tier_emoji(donor_tier()) :: String.t()
  def tier_emoji(:bronze), do: "🥉"
  def tier_emoji(:silver), do: "🥈"
  def tier_emoji(:gold), do: "🥇"
  def tier_emoji(:platinum), do: "💎"

  @doc """
  Get next tier threshold.

  ## Examples
      iex> DonationClient.next_tier_threshold(:bronze)
      {:ok, :silver, 100_000_000}

      iex> DonationClient.next_tier_threshold(:platinum)
      :max_tier
  """
  @spec next_tier_threshold(donor_tier()) :: {:ok, donor_tier(), lamports()} | :max_tier
  def next_tier_threshold(:bronze), do: {:ok, :silver, @tier_silver}
  def next_tier_threshold(:silver), do: {:ok, :gold, @tier_gold}
  def next_tier_threshold(:gold), do: {:ok, :platinum, @tier_platinum}
  def next_tier_threshold(:platinum), do: :max_tier

  # =============================================================================
  # Server Callbacks
  # =============================================================================

  @impl true
  def init(opts) do
    rpc_url = Keyword.get(opts, :rpc_url, "https://api.devnet.solana.com")
    program_id = Keyword.get(opts, :program_id, "DoNaT1on111111111111111111111111111111111111")

    state = %{
      rpc_url: rpc_url,
      program_id: program_id,
      subscribers: []
    }

    Logger.info("DonationClient started with RPC: #{rpc_url}")

    {:ok, state}
  end

  @impl true
  def handle_call({:donate, donor, amount_sol}, _from, state) do
    amount = sol_to_lamports(amount_sol)

    with :ok <- validate_donation(amount),
         {:ok, stats} <- fetch_vault_stats(state),
         :ok <- check_not_paused(stats),
         {:ok, signature} <- send_donation_tx(donor, amount, state),
         {:ok, donor_info} <- fetch_donor_info(donor, state) do

      result = %{
        signature: signature,
        amount: amount,
        donor: donor,
        new_tier: donor_info.tier,
        total_donated: donor_info.total_donated
      }

      # Notify subscribers
      notify_subscribers(state.subscribers, {:donation_event, result})

      {:reply, {:ok, result}, state}
    else
      {:error, reason} = error ->
        Logger.error("Donation failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_vault_stats, _from, state) do
    case fetch_vault_stats(state) do
      {:ok, stats} -> {:reply, {:ok, stats}, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_donor_info, donor}, _from, state) do
    case fetch_donor_info(donor, state) do
      {:ok, info} -> {:reply, {:ok, info}, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:withdraw, admin, amount_sol}, _from, state) do
    amount = sol_to_lamports(amount_sol)

    with {:ok, stats} <- fetch_vault_stats(state),
         :ok <- check_is_admin(admin, stats.admin),
         :ok <- check_sufficient_funds(amount, stats.current_balance),
         {:ok, signature} <- send_withdraw_tx(admin, amount, state) do
      {:reply, {:ok, signature}, state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    new_subscribers = [pid | state.subscribers]
    Logger.info("New subscriber: #{inspect(pid)}")
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  # =============================================================================
  # Private Functions
  # =============================================================================

  defp validate_donation(amount) when amount < @min_donation do
    {:error, {:donation_too_small, amount, @min_donation}}
  end

  defp validate_donation(amount) when amount > @max_donation do
    {:error, {:donation_too_large, amount, @max_donation}}
  end

  defp validate_donation(_amount), do: :ok

  defp check_not_paused(%{is_paused: true}), do: {:error, :contract_paused}
  defp check_not_paused(_stats), do: :ok

  defp check_is_admin(admin, admin), do: :ok
  defp check_is_admin(_caller, _admin), do: {:error, :unauthorized}

  defp check_sufficient_funds(amount, balance) when amount <= balance, do: :ok
  defp check_sufficient_funds(_amount, _balance), do: {:error, :insufficient_funds}

  defp fetch_vault_stats(_state) do
    # Placeholder - would call RPC endpoint
    {:ok, %{
      admin: "Admin123...",
      total_donated: 1_000_000_000,
      total_withdrawn: 0,
      current_balance: 1_000_000_000,
      donation_count: 10,
      unique_donors: 5,
      is_paused: false,
      min_donation_amount: @min_donation,
      max_donation_amount: @max_donation
    }}
  end

  defp fetch_donor_info(donor, _state) do
    # Placeholder - would call RPC endpoint
    total_donated = 500_000_000
    {:ok, %{
      donor: donor,
      total_donated: total_donated,
      donation_count: 3,
      last_donation_timestamp: System.system_time(:second),
      tier: calculate_tier(total_donated)
    }}
  end

  defp send_donation_tx(_donor, _amount, _state) do
    # Placeholder - would build and send transaction
    {:ok, "signature_#{:rand.uniform(1000000)}"}
  end

  defp send_withdraw_tx(_admin, _amount, _state) do
    # Placeholder - would build and send transaction
    {:ok, "withdraw_signature_#{:rand.uniform(1000000)}"}
  end

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn pid ->
      send(pid, message)
    end)
  end
end
