import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { useWeb3Modal } from '@web3modal/ethers/react';

interface WalletState {
  address: string | null;
  balance: string | null;
  chainId: number | null;
  isConnected: boolean;
}

/**
 * WalletConnect Component
 * A modern React component for Web3 wallet integration
 * Supports MetaMask, WalletConnect, Coinbase Wallet, and more
 */
export const WalletConnect: React.FC = () => {
  const { open } = useWeb3Modal();
  const [walletState, setWalletState] = useState<WalletState>({
    address: null,
    balance: null,
    chainId: null,
    isConnected: false,
  });
  const [provider, setProvider] = useState<ethers.BrowserProvider | null>(null);

  // Initialize provider and check connection
  useEffect(() => {
    checkConnection();

    // Listen for account changes
    if (window.ethereum) {
      window.ethereum.on('accountsChanged', handleAccountsChanged);
      window.ethereum.on('chainChanged', handleChainChanged);
      window.ethereum.on('disconnect', handleDisconnect);
    }

    return () => {
      // Cleanup listeners
      if (window.ethereum) {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        window.ethereum.removeListener('chainChanged', handleChainChanged);
        window.ethereum.removeListener('disconnect', handleDisconnect);
      }
    };
  }, []);

  const checkConnection = async () => {
    if (typeof window.ethereum !== 'undefined') {
      try {
        const ethProvider = new ethers.BrowserProvider(window.ethereum);
        const accounts = await ethProvider.listAccounts();

        if (accounts.length > 0) {
          await updateWalletInfo(ethProvider);
        }
      } catch (error) {
        console.error('Error checking connection:', error);
      }
    }
  };

  const handleAccountsChanged = async (accounts: string[]) => {
    if (accounts.length === 0) {
      handleDisconnect();
    } else {
      const ethProvider = new ethers.BrowserProvider(window.ethereum);
      await updateWalletInfo(ethProvider);
    }
  };

  const handleChainChanged = () => {
    window.location.reload();
  };

  const handleDisconnect = () => {
    setWalletState({
      address: null,
      balance: null,
      chainId: null,
      isConnected: false,
    });
    setProvider(null);
  };

  const connectWallet = async () => {
    if (typeof window.ethereum === 'undefined') {
      alert('Please install MetaMask or another Web3 wallet!');
      return;
    }

    try {
      // Request account access
      const ethProvider = new ethers.BrowserProvider(window.ethereum);
      await ethProvider.send('eth_requestAccounts', []);
      await updateWalletInfo(ethProvider);
    } catch (error) {
      console.error('Error connecting wallet:', error);
      alert('Failed to connect wallet');
    }
  };

  const updateWalletInfo = async (ethProvider: ethers.BrowserProvider) => {
    try {
      const signer = await ethProvider.getSigner();
      const address = await signer.getAddress();
      const balance = await ethProvider.getBalance(address);
      const network = await ethProvider.getNetwork();

      setWalletState({
        address,
        balance: ethers.formatEther(balance),
        chainId: Number(network.chainId),
        isConnected: true,
      });
      setProvider(ethProvider);
    } catch (error) {
      console.error('Error updating wallet info:', error);
    }
  };

  const disconnectWallet = () => {
    handleDisconnect();
  };

  const switchNetwork = async (chainId: number) => {
    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${chainId.toString(16)}` }],
      });
    } catch (error: any) {
      // This error code indicates that the chain has not been added to MetaMask
      if (error.code === 4902) {
        alert('Please add this network to your wallet');
      }
      console.error('Error switching network:', error);
    }
  };

  const sendTransaction = async (to: string, amount: string) => {
    if (!provider) {
      alert('Please connect your wallet first');
      return;
    }

    try {
      const signer = await provider.getSigner();
      const tx = await signer.sendTransaction({
        to,
        value: ethers.parseEther(amount),
      });

      console.log('Transaction sent:', tx.hash);
      const receipt = await tx.wait();
      console.log('Transaction confirmed:', receipt);

      // Update balance after transaction
      await updateWalletInfo(provider);

      return receipt;
    } catch (error) {
      console.error('Error sending transaction:', error);
      throw error;
    }
  };

  const signMessage = async (message: string) => {
    if (!provider) {
      alert('Please connect your wallet first');
      return;
    }

    try {
      const signer = await provider.getSigner();
      const signature = await signer.signMessage(message);
      return signature;
    } catch (error) {
      console.error('Error signing message:', error);
      throw error;
    }
  };

  const getChainName = (chainId: number): string => {
    const chains: Record<number, string> = {
      1: 'Ethereum Mainnet',
      5: 'Goerli Testnet',
      11155111: 'Sepolia Testnet',
      137: 'Polygon Mainnet',
      80001: 'Mumbai Testnet',
      42161: 'Arbitrum One',
      10: 'Optimism',
    };
    return chains[chainId] || `Chain ${chainId}`;
  };

  return (
    <div className="wallet-connect">
      <div className="wallet-card">
        <h2>🔐 Wallet Connection</h2>

        {!walletState.isConnected ? (
          <div className="connect-section">
            <p>Connect your wallet to get started</p>
            <button onClick={connectWallet} className="connect-button">
              Connect Wallet
            </button>
            <button onClick={() => open()} className="connect-button secondary">
              WalletConnect
            </button>
          </div>
        ) : (
          <div className="wallet-info">
            <div className="info-item">
              <span className="label">Address:</span>
              <span className="value">
                {walletState.address?.slice(0, 6)}...
                {walletState.address?.slice(-4)}
              </span>
            </div>

            <div className="info-item">
              <span className="label">Balance:</span>
              <span className="value">
                {parseFloat(walletState.balance || '0').toFixed(4)} ETH
              </span>
            </div>

            <div className="info-item">
              <span className="label">Network:</span>
              <span className="value">
                {walletState.chainId && getChainName(walletState.chainId)}
              </span>
            </div>

            <div className="actions">
              <button onClick={disconnectWallet} className="disconnect-button">
                Disconnect
              </button>

              <button
                onClick={() => switchNetwork(11155111)}
                className="network-button"
              >
                Switch to Sepolia
              </button>
            </div>
          </div>
        )}
      </div>

      <style jsx>{`
        .wallet-connect {
          max-width: 500px;
          margin: 2rem auto;
          padding: 2rem;
        }

        .wallet-card {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          border-radius: 20px;
          padding: 2rem;
          color: white;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        }

        h2 {
          margin: 0 0 1.5rem 0;
          font-size: 1.8rem;
          text-align: center;
        }

        .connect-section {
          text-align: center;
        }

        .connect-section p {
          margin-bottom: 1.5rem;
          opacity: 0.9;
        }

        .connect-button {
          width: 100%;
          padding: 1rem;
          margin: 0.5rem 0;
          font-size: 1.1rem;
          font-weight: bold;
          border: none;
          border-radius: 10px;
          background: white;
          color: #667eea;
          cursor: pointer;
          transition: all 0.3s;
        }

        .connect-button:hover {
          transform: translateY(-2px);
          box-shadow: 0 10px 20px rgba(0, 0, 0, 0.2);
        }

        .connect-button.secondary {
          background: rgba(255, 255, 255, 0.1);
          color: white;
          border: 2px solid white;
        }

        .wallet-info {
          background: rgba(255, 255, 255, 0.1);
          padding: 1.5rem;
          border-radius: 15px;
          backdrop-filter: blur(10px);
        }

        .info-item {
          display: flex;
          justify-content: space-between;
          margin: 1rem 0;
          padding: 0.8rem;
          background: rgba(255, 255, 255, 0.05);
          border-radius: 8px;
        }

        .label {
          font-weight: 600;
          opacity: 0.8;
        }

        .value {
          font-family: 'Courier New', monospace;
        }

        .actions {
          margin-top: 1.5rem;
          display: flex;
          gap: 1rem;
        }

        .disconnect-button,
        .network-button {
          flex: 1;
          padding: 0.8rem;
          border: none;
          border-radius: 8px;
          font-weight: bold;
          cursor: pointer;
          transition: all 0.3s;
        }

        .disconnect-button {
          background: #ff6b6b;
          color: white;
        }

        .network-button {
          background: rgba(255, 255, 255, 0.2);
          color: white;
        }

        .disconnect-button:hover,
        .network-button:hover {
          transform: translateY(-2px);
        }
      `}</style>
    </div>
  );
};

export default WalletConnect;
