// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "./BondingCurve.sol";

import "./Math/SafeMath.sol";

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IWETH.sol";

contract PumpToken is BondingCurve {
    using Math for uint256;
    using SafeMath for uint256;

    uint256 private constant TOTAL_SUPPLY_CEILING = 1e9;

    uint256 private constant TOKEN_CREATION_FEE = 1e8 gwei; // 0.1 ETH

    uint256 private constant LISTING_FEE = 1e8 gwei; // 0.1 ETH

    uint256 private constant LISTING_THRESHOLD = 15 ether;

    uint256 private constant LISTING_LIQUIDITY = 7 ether;

    uint16 private constant RESERVE_RATE_BPS = 500; // 5% in basis point

    uint16 private constant FEE_RATE_BPS = 100; // 1% in basis point

    uint16 private constant USER_HOLDINGS_TO_PUMP_THRESHOLD_BPS = 5100; // 51%

    IUniswapV2Router02 public uniswapV2Router;

    IUniswapV2Pair public uniswapPair;

    uint256 public totalRaised;

    uint256 public totalReserve;

    uint256 public totalPumped;

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
        address uniswapV2Router_,
        uint32 reserveRatio_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        reserveRatio = reserveRatio_;
        _launching = true;
        uniswapV2Router = IUniswapV2Router02(uniswapV2Router_);
    }

    modifier onlyWhenLaunching() {
        require(_launching, "This action is on allowed when launching");
        _;
    }

    function buy(uint256 minAmountOut, address recipient) external payable onlyWhenLaunching {
        uint256 tokensToMint = _buy(msg.value, recipient);
        require(tokensToMint >= minAmountOut, "Amount out too small");
    }
    function _buy(uint256 value, address recipient) internal returns (uint256) {
        require(value > 0, "Amount in too small");
        (, , uint256 buyAmount) = _chargeFee(value);
        uint256 tokensToMint = _bcBuy(buyAmount, recipient);
        totalRaised = totalRaised + buyAmount;
        emit Buy(recipient, buyAmount, tokensToMint);
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
        (, , uint256 amountOut) = _chargeFee(bcAmountOut);

        require(amountOut >= minAmountOut, "Amount out too small");

        totalRaised = totalRaised - amountOut;
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
                1e5
            ) <= totalPumped
        ) {
            _buy(totalReserve, address(this));
            emit Pump(totalReserve);
            totalReserve = 0;
        }
    }

    function list() external payable onlyWhenLaunching {
        require(msg.value == LISTING_FEE, "Must pay listing fee");
        require(totalRaised >= LISTING_THRESHOLD, "Total raised must pass the listing threshold");

        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(uniswapV2Router.factory());

        address WETH = uniswapV2Router.WETH();
        uniswapPair = IUniswapV2Pair(uniswapFactory.createPair(address(this), WETH));

        uint256 tokensToList = LISTING_LIQUIDITY.mulDiv(totalSupply(), totalRaised);

        _mint(address(uniswapPair), tokensToList); // mint liquidity amount to the pair

        IWETH(WETH).deposit{value: LISTING_LIQUIDITY}();
        assert(IWETH(WETH).transfer(address(uniswapPair), LISTING_LIQUIDITY)); // transfer weth to the pair
        IUniswapV2Pair(uniswapPair).mint(address(uniswapFactory)); // call low level mint function on pair
        _launching = false;

        emit List(tokensToList);
    }

    function _chargeFee(
        uint256 amount
    ) internal returns (uint256 reserved, uint256 fee, uint256 remaining) {
        reserved = amount.mulDiv(RESERVE_RATE_BPS, 1e5);
        fee = amount.mulDiv(FEE_RATE_BPS, 1e5);
        remaining = amount - reserved - fee;
        totalReserve = totalReserve + reserved;
    }

    function collectFee() external onlyOwner {
      (bool sent, ) = msg.sender.call{value: address(this).balance - totalReserve - totalRaised}("");
      require(sent, "Failed to send fee to the owner");
    }
}
