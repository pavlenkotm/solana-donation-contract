# Keypairs Directory

This directory is for storing keypair JSON files used in development and testing.

## Usage

### Generate a new keypair

```bash
solana-keygen new --outfile keypairs/admin.json
```

### Using with the donation contract

The admin keypair is referenced in `.env` file:

```
ADMIN_KEYPAIR_PATH=./keypairs/admin.json
```

## Security Warning

⚠️ **NEVER commit keypairs containing real funds to version control!**

This directory is included in `.gitignore` to prevent accidental commits.
Only `.gitkeep` and this README are tracked.

## Development Keypairs

For local development:
- `admin.json` - Admin account for the donation vault
- `donor.json` - Test donor account

Generate these with:
```bash
solana-keygen new --outfile keypairs/admin.json
solana-keygen new --outfile keypairs/donor.json
```
