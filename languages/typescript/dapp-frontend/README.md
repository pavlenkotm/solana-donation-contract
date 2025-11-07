# ⚛️ TypeScript/React DApp Frontend

A modern, production-ready Web3 DApp frontend built with React, TypeScript, and Ethers.js.

## ✨ Features

- **Wallet Integration**: MetaMask, WalletConnect, Coinbase Wallet support
- **Network Switching**: Easily switch between networks
- **Transaction Management**: Send transactions with proper error handling
- **Message Signing**: Sign and verify messages
- **Type Safety**: Full TypeScript coverage
- **Modern UI**: Responsive design with smooth animations
- **React Hooks**: Custom hooks for Web3 functionality

## 🛠️ Tech Stack

- **React** 18+
- **TypeScript** 5+
- **Ethers.js** 6+
- **Vite** - Lightning-fast build tool
- **Web3Modal** - Multi-wallet support
- **Wagmi** (optional) - React hooks for Ethereum

## 📋 Prerequisites

```bash
node --version  # v18+
npm --version   # v9+
```

## 🚀 Installation

```bash
cd languages/typescript/dapp-frontend

# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build
```

## 🔨 Usage

### Basic Integration

```tsx
import { WalletConnect } from './WalletConnect';

function App() {
  return (
    <div className="app">
      <WalletConnect />
    </div>
  );
}
```

### Advanced Usage

```tsx
import { ethers } from 'ethers';
import { useState, useEffect } from 'react';

function MyDApp() {
  const [provider, setProvider] = useState<ethers.BrowserProvider | null>(null);
  const [signer, setSigner] = useState<ethers.Signer | null>(null);

  useEffect(() => {
    const init = async () => {
      if (window.ethereum) {
        const web3Provider = new ethers.BrowserProvider(window.ethereum);
        const web3Signer = await web3Provider.getSigner();

        setProvider(web3Provider);
        setSigner(web3Signer);
      }
    };
    init();
  }, []);

  const sendTransaction = async () => {
    if (!signer) return;

    const tx = await signer.sendTransaction({
      to: '0x...',
      value: ethers.parseEther('0.1')
    });

    await tx.wait();
    console.log('Transaction confirmed!');
  };

  return (
    <button onClick={sendTransaction}>
      Send 0.1 ETH
    </button>
  );
}
```

## 📖 Component API

### WalletConnect Component

```tsx
interface WalletState {
  address: string | null;
  balance: string | null;
  chainId: number | null;
  isConnected: boolean;
}
```

#### Methods

- `connectWallet()`: Connect to Web3 wallet
- `disconnectWallet()`: Disconnect wallet
- `switchNetwork(chainId)`: Switch to different network
- `sendTransaction(to, amount)`: Send ETH transaction
- `signMessage(message)`: Sign message with wallet

## 🎨 Customization

### Styling

```tsx
// Custom theme
const theme = {
  colors: {
    primary: '#667eea',
    secondary: '#764ba2',
    background: '#1a1a2e',
  }
};
```

### Supported Networks

```typescript
const networks = {
  1: 'Ethereum Mainnet',
  5: 'Goerli',
  11155111: 'Sepolia',
  137: 'Polygon',
  42161: 'Arbitrum',
  10: 'Optimism',
};
```

## 🧪 Testing

```bash
# Install testing dependencies
npm install --save-dev @testing-library/react vitest

# Run tests
npm test

# Run with coverage
npm test -- --coverage
```

### Example Test

```tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { WalletConnect } from './WalletConnect';

test('renders connect button', () => {
  render(<WalletConnect />);
  const button = screen.getByText(/Connect Wallet/i);
  expect(button).toBeInTheDocument();
});

test('connects wallet on button click', async () => {
  render(<WalletConnect />);
  const button = screen.getByText(/Connect Wallet/i);

  fireEvent.click(button);

  // Wait for wallet to connect
  await screen.findByText(/Disconnect/i);
});
```

## 📚 Custom Hooks

### useWallet Hook

```tsx
import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

export const useWallet = () => {
  const [provider, setProvider] = useState<ethers.BrowserProvider | null>(null);
  const [address, setAddress] = useState<string | null>(null);
  const [balance, setBalance] = useState<string>('0');

  const connect = async () => {
    if (!window.ethereum) {
      throw new Error('No wallet found');
    }

    const web3Provider = new ethers.BrowserProvider(window.ethereum);
    await web3Provider.send('eth_requestAccounts', []);

    const signer = await web3Provider.getSigner();
    const addr = await signer.getAddress();
    const bal = await web3Provider.getBalance(addr);

    setProvider(web3Provider);
    setAddress(addr);
    setBalance(ethers.formatEther(bal));
  };

  const disconnect = () => {
    setProvider(null);
    setAddress(null);
    setBalance('0');
  };

  return { provider, address, balance, connect, disconnect };
};
```

### useContract Hook

```tsx
import { ethers } from 'ethers';
import { useState, useEffect } from 'react';

export const useContract = (address: string, abi: any[]) => {
  const [contract, setContract] = useState<ethers.Contract | null>(null);

  useEffect(() => {
    const init = async () => {
      if (window.ethereum) {
        const provider = new ethers.BrowserProvider(window.ethereum);
        const signer = await provider.getSigner();
        const contractInstance = new ethers.Contract(address, abi, signer);
        setContract(contractInstance);
      }
    };
    init();
  }, [address, abi]);

  return contract;
};
```

## 🔐 Security Best Practices

1. **Never store private keys in frontend**
2. **Validate all user inputs**
3. **Use checksummed addresses**
4. **Implement proper error handling**
5. **Use HTTPS in production**

```tsx
// Good practices
const isValidAddress = (address: string) => {
  try {
    ethers.getAddress(address);
    return true;
  } catch {
    return false;
  }
};

const sanitizeInput = (input: string) => {
  return input.trim().toLowerCase();
};
```

## 📱 Responsive Design

```css
@media (max-width: 768px) {
  .wallet-card {
    padding: 1rem;
  }

  .actions {
    flex-direction: column;
  }
}
```

## 🌐 Deployment

### Vercel

```bash
npm install -g vercel
vercel deploy
```

### Netlify

```bash
npm run build
netlify deploy --dir=dist
```

### IPFS

```bash
npm run build
ipfs add -r dist/
```

## 📊 Performance Optimization

1. **Code Splitting**
```tsx
const WalletConnect = lazy(() => import('./WalletConnect'));
```

2. **Memoization**
```tsx
const memoizedValue = useMemo(() => expensiveComputation(), [deps]);
```

3. **Lazy Loading**
```tsx
import { lazy, Suspense } from 'react';
```

## 🔗 Integration Examples

### With Smart Contracts

```tsx
const ERC20_ABI = [...];
const contract = new ethers.Contract(TOKEN_ADDRESS, ERC20_ABI, signer);

// Read balance
const balance = await contract.balanceOf(address);

// Send transaction
const tx = await contract.transfer(recipient, amount);
await tx.wait();
```

### With ENS

```tsx
const resolveENS = async (name: string) => {
  const address = await provider.resolveName(name);
  return address;
};

const ensName = await provider.lookupAddress(address);
```

## 📄 License

MIT License

## 🎓 Resources

- [React Documentation](https://react.dev/)
- [Ethers.js v6 Docs](https://docs.ethers.org/v6/)
- [Web3Modal](https://web3modal.com/)
- [Wagmi Hooks](https://wagmi.sh/)
- [Vite Guide](https://vitejs.dev/)
