const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SimpleToken", function () {
  let token;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  const TOKEN_NAME = "SimpleToken";
  const TOKEN_SYMBOL = "SIMP";
  const INITIAL_SUPPLY = ethers.parseEther("1000000");
  const DECIMALS = 18;
  const MAX_SUPPLY = ethers.parseEther("10000000");

  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const SimpleToken = await ethers.getContractFactory("SimpleToken");
    token = await SimpleToken.deploy(
      TOKEN_NAME,
      TOKEN_SYMBOL,
      INITIAL_SUPPLY,
      DECIMALS,
      MAX_SUPPLY
    );
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await token.owner()).to.equal(owner.address);
    });

    it("Should assign the total supply to the owner", async function () {
      const ownerBalance = await token.balanceOf(owner.address);
      expect(await token.totalSupply()).to.equal(ownerBalance);
    });

    it("Should set correct name and symbol", async function () {
      expect(await token.name()).to.equal(TOKEN_NAME);
      expect(await token.symbol()).to.equal(TOKEN_SYMBOL);
    });

    it("Should set correct decimals", async function () {
      expect(await token.decimals()).to.equal(DECIMALS);
    });

    it("Should set correct max supply", async function () {
      expect(await token.maxSupply()).to.equal(MAX_SUPPLY);
    });
  });

  describe("Minting", function () {
    it("Should allow owner to mint tokens", async function () {
      const mintAmount = ethers.parseEther("1000");
      await token.mint(addr1.address, mintAmount);
      expect(await token.balanceOf(addr1.address)).to.equal(mintAmount);
    });

    it("Should not allow non-owner to mint", async function () {
      const mintAmount = ethers.parseEther("1000");
      await expect(
        token.connect(addr1).mint(addr1.address, mintAmount)
      ).to.be.reverted;
    });

    it("Should not exceed max supply", async function () {
      const tooMuch = MAX_SUPPLY;
      await expect(
        token.mint(addr1.address, tooMuch)
      ).to.be.revertedWith("Minting would exceed max supply");
    });

    it("Should emit TokensMinted event", async function () {
      const mintAmount = ethers.parseEther("1000");
      await expect(token.mint(addr1.address, mintAmount))
        .to.emit(token, "TokensMinted")
        .withArgs(addr1.address, mintAmount);
    });
  });

  describe("Burning", function () {
    it("Should allow burning own tokens", async function () {
      const burnAmount = ethers.parseEther("100");
      await token.burn(burnAmount);
      expect(await token.balanceOf(owner.address)).to.equal(
        INITIAL_SUPPLY - burnAmount
      );
    });

    it("Should decrease total supply when burning", async function () {
      const burnAmount = ethers.parseEther("100");
      await token.burn(burnAmount);
      expect(await token.totalSupply()).to.equal(INITIAL_SUPPLY - burnAmount);
    });
  });

  describe("Batch Transfer", function () {
    it("Should batch transfer to multiple addresses", async function () {
      const amount = ethers.parseEther("100");
      const recipients = [addr1.address, addr2.address];
      const amounts = [amount, amount];

      await token.batchTransfer(recipients, amounts);

      expect(await token.balanceOf(addr1.address)).to.equal(amount);
      expect(await token.balanceOf(addr2.address)).to.equal(amount);
    });

    it("Should revert if arrays have different lengths", async function () {
      const recipients = [addr1.address];
      const amounts = [ethers.parseEther("100"), ethers.parseEther("100")];

      await expect(
        token.batchTransfer(recipients, amounts)
      ).to.be.revertedWith("Arrays must have same length");
    });

    it("Should revert if array is empty", async function () {
      await expect(
        token.batchTransfer([], [])
      ).to.be.revertedWith("Empty arrays");
    });
  });

  describe("Max Supply Updates", function () {
    it("Should allow owner to update max supply", async function () {
      const newMaxSupply = ethers.parseEther("20000000");
      await token.updateMaxSupply(newMaxSupply);
      expect(await token.maxSupply()).to.equal(newMaxSupply);
    });

    it("Should not allow setting max supply below current supply", async function () {
      const tooLow = ethers.parseEther("100");
      await expect(
        token.updateMaxSupply(tooLow)
      ).to.be.revertedWith("New max supply must be >= current supply");
    });

    it("Should emit MaxSupplyUpdated event", async function () {
      const newMaxSupply = ethers.parseEther("20000000");
      await expect(token.updateMaxSupply(newMaxSupply))
        .to.emit(token, "MaxSupplyUpdated")
        .withArgs(MAX_SUPPLY, newMaxSupply);
    });
  });
});
