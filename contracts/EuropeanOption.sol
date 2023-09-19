//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";

contract EuropeanOption is ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    address public immutable baseToken;
    address public immutable quoteToken;
    uint public immutable strikePriceRatio;
    uint public immutable expirationDate;

    uint totalShare;

    IPermit2 public immutable permit2;
    address public broker;
    uint256 strikePriceDenominator;

    mapping(address => uint) public makersShare;

    modifier isExpierd() {
        require(
            block.timestamp > expirationDate,
            "ERROR : Option has not expired"
        );
        _;
    }

    modifier isNotExpierd() {
        require(
            block.timestamp <= expirationDate,
            "ERROR : Option has expired"
        );
        _;
    }

    modifier isExercisable() {
        require(
            block.timestamp + 1 days > expirationDate,
            "ERROR : Option is not exercisable"
        );
        _;
    }

    modifier onlyBroker() {
        require(msg.sender == broker, "UNAUTHORIZED");

        _;
    }

    constructor(
        address _baseToken,
        address _quoteToken,
        uint _strikePriceRatio,
        uint _expirationDate,
        uint8 _baseTokenDecimals,
        IPermit2 _permit2,
        address _broker
    ) ERC20("EuropeanOption", "EOPT", _baseTokenDecimals) {
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        strikePriceRatio = _strikePriceRatio;
        expirationDate = _expirationDate;
        permit2 = _permit2;
        broker = _broker;
        strikePriceDenominator = 10 ** _baseTokenDecimals;
    }

    function issue(
        address maker,
        address taker,
        uint amount
    ) external isNotExpierd nonReentrant onlyBroker {
        require(amount != 0, "ERROR: optionAmount cannot be zero");

        permit2.transferFrom(maker, address(this), uint160(amount), baseToken);
        _mint(taker, amount);
        totalShare += amount;
        makersShare[maker] += amount;
    }

    function exercise(
        address owner,
        uint amount,
        IPermit2.PermitSingle memory permitSingle,
        bytes memory signature
    ) external nonReentrant isExercisable isNotExpierd {
        IERC20(baseToken).transfer(owner, amount);
        _burn(owner, amount);

        amount = amount.mul(strikePriceRatio).div(strikePriceDenominator);
        uint256 userAllowance = IERC20(quoteToken).allowance(
            owner,
            address(this)
        );
        if (amount >= userAllowance)
            permit2.permit(owner, permitSingle, signature);

        permit2.transferFrom(owner, address(this), uint160(amount), quoteToken);
    }

    function collect(address recipient) external nonReentrant isExpierd {
        uint baseTokenAmount = totalSupply.mul(makersShare[msg.sender]).div(
            totalShare
        );
        IERC20(baseToken).transfer(recipient, baseTokenAmount);

        uint quoteTokenAmount = (
            totalShare.sub(totalSupply).mul(strikePriceRatio).div(
                strikePriceDenominator
            )
        ).mul(makersShare[msg.sender]).div(totalShare);
        IERC20(baseToken).transfer(recipient, quoteTokenAmount);
    }

    function brokerSwap(
        address maker,
        address taker,
        uint amount
    ) external onlyBroker {
        balanceOf[maker] -= amount;
        balanceOf[taker] += amount;

        emit Transfer(maker, taker, amount);
    }
}
