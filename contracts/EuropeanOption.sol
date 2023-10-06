//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";

/**
 * @title AmericanOption
 * @dev A contract for European options trading
 */
contract EuropeanOption is ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    address public immutable baseToken;
    address public immutable quoteToken;
    uint public immutable strikePriceRatio;
    uint public immutable expirationDate;

    event issued(address maker , address taker , uint amount , address optionContractAddress);


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

    /**
     * @dev Constructor function
     * @param _baseToken The address of the base token
     * @param _quoteToken The address of the quote token
     * @param _strikePriceRatio The ratio of the strike price to the base token
     * @param _expirationDate The expiration date of the option
     * @param _baseTokenDecimals The number of decimals of the base token
     * @param _permit2 The address of the permit2 contract
     * @param _broker The address of the broker
     */
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

    /**
     * @dev Issues an option
     * @param maker The address of the option maker
     * @param taker The address of the option taker
     * @param amount The amount of the option to be issued
     */
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
        emit issued(maker ,taker , amount , address(this));

    }

    /**
     * @dev Exercises an option
     * @param amount The amount of the option to be exercised
     * @param permitSingle The permit information for the quote token
     * @param signature The signature for the permit
     */
    function exercise(
        uint amount,
        IPermit2.PermitSingle memory permitSingle,
        bytes memory signature
    ) external nonReentrant isExercisable isNotExpierd {

        require(balanceOf[msg.sender] >= amount , "ERROR : insufficient option amount");

        uint permiumAmount = amount.mul(strikePriceRatio).div(strikePriceDenominator);
        (uint160 userAllowance, uint48 expiration,) = permit2.allowance(msg.sender , quoteToken , address(this));
        if (permiumAmount >= userAllowance || expiration <= block.timestamp)
            permit2.permit(msg.sender, permitSingle, signature);

        permit2.transferFrom(msg.sender, address(this), uint160(permiumAmount), quoteToken);
       
        _burn(msg.sender, amount);
        IERC20(baseToken).transfer(msg.sender, amount);
    }

    /**
     * @dev Collects the payout for an option
     * @param recipient The address of the recipient of the payout
     */
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

    /**
     * @dev Swaps an option between two parties
     * @param maker The address of the option maker
     * @param taker The address of the option taker
     * @param amount The amount of the option to be swapped
     */
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
