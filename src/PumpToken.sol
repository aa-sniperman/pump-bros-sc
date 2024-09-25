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

    address public factory;

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
        address factory_,
        uint32 reserveRatio_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        factory = factory_;
        reserveRatio = reserveRatio_;
        _launching = true;
        uniswapV2Router = IUniswapV2Router02(
            0xc7bFC828C49A14beA1e6c56fDe2545b19F1CC31E
        );
    }

    modifier onlyWhenLaunching() {
        require(_launching);
        _;
    }

    function buy(address recipient) external payable onlyWhenLaunching {
        _buy(msg.value, recipient);
    }
    function _buy(uint256 value, address recipient) internal {
        require(value > 0);
        (, , uint256 buyAmount) = _chargeFee(value);
        uint256 tokensToMint = _bcBuy(buyAmount, recipient);
        totalRaised = totalRaised + buyAmount;
        emit Buy(recipient, buyAmount, tokensToMint);
    }

    function sell(
        uint256 sellAmount,
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
        totalRaised = totalRaised - amountOut;
        (bool sent, ) = recipient.call{value: amountOut}("");
        require(sent);
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
        require(msg.value == LISTING_FEE);
        require(totalRaised >= LISTING_THRESHOLD);

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

    function collectFee() external {
      (bool sent, ) = factory.call{value: address(this).balance - totalReserve - totalRaised}("");
      require(sent);
    }
}
