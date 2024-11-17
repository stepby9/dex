// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DEX Template
 * @notice A decentralized exchange for ETH and ERC20 tokens.
 * @dev Uses the constant product formula for automated market making.
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    IERC20 public token; // The ERC20 token being traded
    mapping(address => uint256) public liquidity; // Tracks liquidity provided by each user
    uint256 public totalLiquidity; // Total liquidity in the pool

    /* ========== EVENTS ========== */

    event EthToTokenSwap(address indexed swapper, uint256 tokenOutput, uint256 ethInput);
    event TokenToEthSwap(address indexed swapper, uint256 tokensInput, uint256 ethOutput);
    event LiquidityProvided(
        address indexed liquidityProvider,
        uint256 liquidityMinted,
        uint256 ethInput,
        uint256 tokensInput
    );
    event LiquidityRemoved(
        address indexed liquidityRemover,
        uint256 liquidityWithdrawn,
        uint256 tokensOutput,
        uint256 ethOutput
    );

    /* ========== CONSTRUCTOR ========== */

    constructor(address tokenAddr) {
        token = IERC20(tokenAddr); // Initialize the token contract
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Initializes the DEX with ETH and tokens.
     * @param tokens The amount of tokens to deposit initially.
     * @return totalLiquidity The total liquidity tokens minted.
     */
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "Already initialized");
        require(msg.value > 0, "Must provide ETH");

        // Transfer tokens from sender to DEX
        require(token.transferFrom(msg.sender, address(this), tokens), "Token transfer failed");

        totalLiquidity = address(this).balance; // Initial liquidity = ETH balance
        liquidity[msg.sender] = totalLiquidity; // Mint liquidity tokens to the provider

        return totalLiquidity;
    }

    /**
     * @notice Calculates the output amount of one asset given an input amount of another.
     * @param xInput Amount of input asset.
     * @param xReserves Reserves of the input asset.
     * @param yReserves Reserves of the output asset.
     * @return yOutput The calculated output amount.
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        uint256 xInputWithFee = xInput * 997; // Apply a 0.3% fee
        uint256 numerator = xInputWithFee * yReserves;
        uint256 denominator = (xReserves * 1000) + xInputWithFee;
        return numerator / denominator;
    }

    /**
     * @notice Swaps ETH for tokens.
     * @return tokenOutput The amount of tokens received.
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "Must send ETH");

        uint256 ethReserves = address(this).balance - msg.value;
        uint256 tokenReserves = token.balanceOf(address(this));

        // Calculate the token output
        tokenOutput = price(msg.value, ethReserves, tokenReserves);

        // Transfer tokens to the sender
        require(token.transfer(msg.sender, tokenOutput), "Token transfer failed");

        emit EthToTokenSwap(msg.sender, tokenOutput, msg.value);
    }

    /**
     * @notice Swaps tokens for ETH.
     * @param tokenInput The amount of tokens to send to the DEX.
     * @return ethOutput The amount of ETH received.
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "Must send tokens");

        uint256 ethReserves = address(this).balance;
        uint256 tokenReserves = token.balanceOf(address(this));

        // Calculate the ETH output
        ethOutput = price(tokenInput, tokenReserves, ethReserves);

        // Transfer tokens to the DEX
        require(token.transferFrom(msg.sender, address(this), tokenInput), "Token transfer failed");

        // Send ETH to the sender
        (bool success, ) = msg.sender.call{value: ethOutput}("");
        require(success, "ETH transfer failed");

        emit TokenToEthSwap(msg.sender, tokenInput, ethOutput);
    }

    /**
     * @notice Provides liquidity to the pool.
     * @return tokensDeposited The amount of tokens deposited.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
    require(msg.value > 0, "Deposit requires a non-zero ETH amount");

    uint256 ethReserve = address(this).balance - msg.value; // ETH reserve before the deposit
    uint256 tokenReserve = token.balanceOf(address(this));

    // Calculate the amount of tokens needed to maintain the ratio
    uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve;

    // Ensure the user provides sufficient token allowance
    require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");

    // Mint liquidity tokens proportional to the ETH deposit
    uint256 liquidityMinted = (msg.value * totalLiquidity) / ethReserve;

    // Update total liquidity
    totalLiquidity += liquidityMinted;

    // Track the user's liquidity
    liquidity[msg.sender] += liquidityMinted;

    // Emit the event
    emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokenAmount);

    return tokenAmount;
}



    /**
     * @notice Withdraws liquidity from the pool.
     * @param amount The amount of liquidity tokens to burn.
     * @return ethAmount The amount of ETH withdrawn.
     * @return tokenAmount The amount of tokens withdrawn.
     */
    function withdraw(uint256 amount) public returns (uint256 ethAmount, uint256 tokenAmount) {
        require(liquidity[msg.sender] >= amount, "Insufficient liquidity");

        uint256 ethReserves = address(this).balance;
        uint256 tokenReserves = token.balanceOf(address(this));

        // Calculate amounts to withdraw
        ethAmount = (amount * ethReserves) / totalLiquidity;
        tokenAmount = (amount * tokenReserves) / totalLiquidity;

        // Burn liquidity tokens
        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;

        // Transfer ETH and tokens to the sender
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");

        emit LiquidityRemoved(msg.sender, amount, tokenAmount, ethAmount);
    }

    /**
     * @notice Returns the liquidity balance of a user.
     * @param lp The address of the liquidity provider.
     * @return The liquidity balance of the user.
     */
    function getLiquidity(address lp) public view returns (uint256) {
        return liquidity[lp];
    }
}
