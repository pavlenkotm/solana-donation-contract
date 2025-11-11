# Elixir Solana Donation Client

A fault-tolerant, concurrent Solana donation contract client built with Elixir, demonstrating the power of the BEAM VM for blockchain interactions.

## Features

- **Concurrency**: Leverage OTP (Open Telecom Platform) for concurrent operations
- **Fault Tolerance**: Supervision trees ensure resilience
- **Pattern Matching**: Clean, expressive code with pattern matching
- **GenServer**: State management with battle-tested abstractions
- **Hot Code Reloading**: Update code without downtime

## Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- Mix (build tool)
- Dependencies: `jason`, `httpoison`, `ex_solana`

## Installation

```bash
mix deps.get
mix compile
```

## Project Structure

```
lib/
  ├── donation_client.ex         # Main client module
  ├── donation_client/
  │   ├── rpc.ex                # RPC client
  │   ├── transaction.ex        # Transaction builder
  │   └── supervisor.ex         # OTP supervisor
  └── donation_client/
      └── schemas/
          ├── vault_stats.ex    # Vault statistics schema
          └── donor_info.ex     # Donor info schema
```

## Usage

```elixir
# Start the client
{:ok, pid} = DonationClient.start_link()

# Make a donation
{:ok, result} = DonationClient.donate(donor_pubkey, 0.5)

# Get vault statistics
{:ok, stats} = DonationClient.get_vault_stats()

# Get donor information with pattern matching
case DonationClient.get_donor_info(donor_pubkey) do
  {:ok, %{tier: :platinum}} ->
    IO.puts("You're a platinum donor!")
  {:ok, %{tier: tier}} ->
    IO.puts("Your tier: #{tier}")
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

## Benefits of Elixir

1. **Immutability**: All data structures are immutable
2. **Concurrency**: Lightweight processes (not OS threads)
3. **Distribution**: Built-in support for distributed systems
4. **Fault Tolerance**: "Let it crash" philosophy with supervisors
5. **Scalability**: Handles millions of processes efficiently
