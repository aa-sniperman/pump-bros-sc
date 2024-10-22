// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./BondingCurve.sol";

import "./Math/SafeMath.sol";

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IWETH.sol";

// Only for testing
import {console} from "forge-std/console.sol";

contract PumpToken is BondingCurve, UUPSUpgradeable, OwnableUpgradeable {
    using Math for uint256;
    using SafeMath for uint256;

    uint256 private constant TOTAL_SUPPLY_CEILING = 1e27; // 1 billion

    uint256 private constant TOKEN_CREATION_FEE = 0.5 ether; // 0.5 ETH

    uint256 private constant LISTING_FEE = 1 ether; // 1 ETH

    uint256 private constant SLOPE = 7664811483415976000;

    uint256 private constant LISTING_THRESHOLD = 366.67 ether;

    uint256 private constant LISTING_LIQUIDITY = 155.56 ether;

    uint16 private constant RESERVE_RATE_BPS = 500; // 5% in basis point

    uint16 private constant FEE_RATE_BPS = 100; // 1% in basis point

    uint16 private constant USER_HOLDINGS_TO_PUMP_THRESHOLD_BPS = 5100; // 51%

    uint256 public totalRaised;

    uint256 public totalReserve;

    uint256 public totalPumped;

    uint256 public selfBought;

    IUniswapV2Router02 public uniswapV2Router;

    IUniswapV2Pair public uniswapPair;

    bool private _launching;

    mapping(address => uint256) public pumped;

    event Buy(
        address indexed recipient,
        uint256 buyAmount,
        uint256 tokensToMint
    );
    event Sell(
        address indexed recipient,
        uint256 sellAmount,
        uint256 amountOut
    );
    event UserPump(address indexed pumper, uint256 amount);
    event Pump(uint256 reserved);
    event List(uint256 tokensToList);

    function initialize(
        string memory name_,
        string memory symbol_,
        address owner_,
        address creator_,
        address uniswapV2Router_
    ) external payable initializer {
        require(msg.value >= TOKEN_CREATION_FEE + LISTING_FEE, "Not enough money to pay token creation & listing fee");
        __ERC20_init(name_, symbol_);
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        reserveRatio = 444444;
        
        uint256 value = msg.value - TOKEN_CREATION_FEE - LISTING_FEE;

        (, , uint256 initialDeposit, uint256 spare) = _chargeFee(value, LISTING_THRESHOLD);

        uint256 initialTokens = _bcInitialBuy(initialDeposit, SLOPE, creator_);

        totalRaised = totalRaised + initialDeposit;

        emit Buy(creator_, initialDeposit, initialTokens);

        _launching = true;
        uniswapV2Router = IUniswapV2Router02(uniswapV2Router_);

        _refundSpare(spare, creator_);
    }

    modifier onlyWhenLaunching() {
        require(_launching, "This action is on allowed when launching");
        _;
    }

    function buy(
        uint256 minAmountOut,
        address recipient
    ) external payable onlyWhenLaunching {
        uint256 tokensToMint = _buy(msg.value, recipient);
        console.log("tokens to mint: %d", tokensToMint);
        require(tokensToMint >= minAmountOut, "Amount out too small");
    }
    function _buy(uint256 value, address recipient) internal returns (uint256) {
        require(value > 0, "Amount in too small");
        (, , uint256 buyAmount, uint256 spare) = _chargeFee(value, LISTING_THRESHOLD - totalRaised);
        uint256 tokensToMint = _bcBuy(buyAmount, recipient);
        totalRaised = totalRaised + buyAmount;
        _refundSpare(spare, msg.sender);
        emit Buy(recipient, buyAmount, tokensToMint);

        if(totalRaised >= LISTING_THRESHOLD) {
            list();
        }
        return tokensToMint;
    }

    function sell(
        uint256 sellAmount,
        uint256 minAmountOut,
        address recipient
    ) external onlyWhenLaunching {
        // remove pumped
        uint256 currentPumped = pumped[msg.sender];
        uint256 pumpToRemove = Math.min(sellAmount, currentPumped);
        pumped[msg.sender] = currentPumped - pumpToRemove;
        totalPumped = totalPumped - pumpToRemove;

        // burn token and transfer out
        uint256 bcAmountOut = _bcSell(msg.sender, sellAmount);
        
        totalRaised = totalRaised - bcAmountOut;

        (, , uint256 amountOut,) = _chargeFee(bcAmountOut, totalRaised);

        require(amountOut >= minAmountOut, "Amount out too small");

        (bool sent, ) = recipient.call{value: amountOut}("");
        require(sent, "Failed to redeem funds");
        emit Sell(recipient, sellAmount, amountOut);
    }

    function pump(uint256 amount) external onlyWhenLaunching {
        uint256 currentPumped = pumped[msg.sender];
        uint256 amountToPump = Math.min(
            amount,
            balanceOf(msg.sender) - currentPumped
        );
        pumped[msg.sender] = currentPumped + amountToPump;
        totalPumped = totalPumped + amountToPump;
        emit UserPump(msg.sender, amountToPump);

        if (
            (TOTAL_SUPPLY_CEILING.safeMinus(totalSupply())).mulDiv(
                USER_HOLDINGS_TO_PUMP_THRESHOLD_BPS,
                1e4
            ) <= totalPumped
        ) {

            uint256 bought = _bcBuy(totalReserve, address(this));

            selfBought = selfBought + bought;
            totalRaised = totalRaised + totalReserve;

            if(totalRaised >= LISTING_THRESHOLD) {
                list();
            }
            
            emit Pump(totalReserve);
            totalReserve = 0;
        }
    }

    function list() public onlyWhenLaunching {
        require(
            totalRaised >= LISTING_THRESHOLD,
            "Total raised must pass the listing threshold"
        );

        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(
            uniswapV2Router.factory()
        );

        address WETH = uniswapV2Router.WETH();
        uniswapPair = IUniswapV2Pair(
            uniswapFactory.createPair(address(this), WETH)
        );

        uint256 tokensToMint = TOTAL_SUPPLY_CEILING - totalSupply();

        _mint(address(this), tokensToMint);

        uint256 tokensToList = selfBought + tokensToMint;

        _transfer(address(this), address(uniswapPair), tokensToList); // mint liquidity amount to the pair

        IWETH(WETH).deposit{value: LISTING_LIQUIDITY}();
        assert(IWETH(WETH).transfer(address(uniswapPair), LISTING_LIQUIDITY)); // transfer weth to the pair
        IUniswapV2Pair(uniswapPair).mint(address(uniswapFactory)); // call low level mint function on pair
        _launching = false;

        emit List(tokensToList);
    }

    function _chargeFee(
        uint256 amount,
        uint256 maxActual
    ) internal returns (uint256 reserved, uint256 fee, uint256 actual, uint256 spare) {
        uint256 actualRate = 1e4 - RESERVE_RATE_BPS - FEE_RATE_BPS;
        uint256 amountAfterRate = amount.mulDiv(actualRate, 1e4);
        actual = Math.min(maxActual, amountAfterRate);
        reserved = actual.mulDiv(RESERVE_RATE_BPS, actualRate);
        fee = actual.mulDiv(FEE_RATE_BPS, actualRate);
        spare = amountAfterRate - actual;
        totalReserve = totalReserve + reserved;
    }

    function _refundSpare(uint256 spare, address recipient) internal {
        if(spare > 0) {
            (bool sent, ) = recipient.call{
                value: spare
            }("");
            require(sent, "Failed to refund spare");
        }
    }

    function collectFee() external onlyOwner {
        (bool sent, ) = msg.sender.call{
            value: address(this).balance - totalReserve - totalRaised
        }("");
        require(sent, "Failed to send fee to the owner");
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
