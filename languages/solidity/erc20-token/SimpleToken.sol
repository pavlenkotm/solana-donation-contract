// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleToken
 * @dev ERC-20 token with burn capability and ownership controls
 * @notice This token demonstrates standard ERC-20 functionality with OpenZeppelin
 */
contract SimpleToken is ERC20, ERC20Burnable, Ownable {
    uint8 private _decimals;
    uint256 public maxSupply;

    event TokensMinted(address indexed to, uint256 amount);
    event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);

    /**
     * @dev Constructor that gives msg.sender all of initial supply
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial token supply (in wei)
     * @param tokenDecimals Number of decimals for the token
     * @param _maxSupply Maximum supply cap (0 for unlimited)
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 tokenDecimals,
        uint256 _maxSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = tokenDecimals;
        maxSupply = _maxSupply;

        require(
            _maxSupply == 0 || initialSupply <= _maxSupply,
            "Initial supply exceeds max supply"
        );

        _mint(msg.sender, initialSupply);
        emit TokensMinted(msg.sender, initialSupply);
    }

    /**
     * @dev Returns the number of decimals used for token amounts
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Mints new tokens (only owner)
     * @param to Address to receive minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) public onlyOwner {
        if (maxSupply > 0) {
            require(
                totalSupply() + amount <= maxSupply,
                "Minting would exceed max supply"
            );
        }
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Updates the maximum supply cap (only owner)
     * @param newMaxSupply New maximum supply (must be >= current supply)
     */
    function updateMaxSupply(uint256 newMaxSupply) public onlyOwner {
        require(
            newMaxSupply == 0 || newMaxSupply >= totalSupply(),
            "New max supply must be >= current supply"
        );
        uint256 oldMaxSupply = maxSupply;
        maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(oldMaxSupply, newMaxSupply);
    }

    /**
     * @dev Batch transfer to multiple addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer
     */
    function batchTransfer(
        address[] memory recipients,
        uint256[] memory amounts
    ) public returns (bool) {
        require(
            recipients.length == amounts.length,
            "Arrays must have same length"
        );
        require(recipients.length > 0, "Empty arrays");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid recipient");
            require(amounts[i] > 0, "Amount must be > 0");
            _transfer(msg.sender, recipients[i], amounts[i]);
        }

        return true;
    }
}
