// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";

/**
 * @title AmericanOption
 * @dev A contract for American options trading
 */
contract AmericanOption is ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    // Struct to store information about an issuance
    struct IssueInfo {
        uint share;
        uint32 stageJoined;
    }

    // Struct to store information about an option maker
    struct OptionMaker {
        uint totalShare;
        uint collected;
        IssueInfo[] issuances;
    }

    // Events
    event issued(address maker, address taker, uint amount, address optionContractAddress);

    // Variables
    uint[] stageShare;
    uint public immutable strikePriceRatio;
    uint public immutable expirationDate;
    uint totalShare;

    // Immutable variables
    address public immutable baseToken;
    address public immutable quoteToken;
    IPermit2 public immutable permit2;
    address public broker;
    uint256 public strikePriceDenominator;

    // Mapping to store information about option makers
    mapping(address => OptionMaker) public optionMakers;

    // Modifiers
    modifier isExpierd() {
        require(block.timestamp > expirationDate, "ERROR: Option has not expired");
        _;
    }

    modifier isNotExpierd() {
        require(block.timestamp <= expirationDate, "ERROR: Option has expired");
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
    ) ERC20("AmericanOption", "AOPT", _baseTokenDecimals) {
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
    ) external nonReentrant onlyBroker {
        require(amount != 0, "ERROR: optionAmount cannot be zero");

        permit2.transferFrom(maker, address(this), uint160(amount), baseToken);

        _mint(taker, amount);
        totalShare += amount;

        optionMakers[maker].totalShare += amount;

        optionMakers[maker].issuances.push(
            IssueInfo(amount, uint32(stageShare.length))
        );
        emit issued(maker, taker, amount, address(this));
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
    ) external nonReentrant isNotExpierd {
        require(balanceOf[msg.sender] >= amount, "ERROR: insufficient option amount");

        uint permiumAmount = amount.mul(strikePriceRatio).div(strikePriceDenominator);
        (uint160 userAllowance, uint48 expiration,) = permit2.allowance(msg.sender, quoteToken, address(this));
        if (permiumAmount >= userAllowance || expiration <= block.timestamp)
            permit2.permit(msg.sender, permitSingle, signature);

        permit2.transferFrom(msg.sender, address(this), uint160(permiumAmount), quoteToken);
        stageShare.push(permiumAmount.mul(10 ** decimals).div(totalSupply));

        _burn(msg.sender, amount);
        IERC20(baseToken).transfer(msg.sender, amount);
    }

    /**
     * @dev Collects the payout for an option
     * @param recipient The address of the recipient of the payout
     */
    function collect(address recipient) external nonReentrant {
        if (block.timestamp > expirationDate) {
            uint baseTokenAmount = totalSupply.mul(optionMakers[msg.sender].totalShare).div(totalShare);
            IERC20(baseToken).transfer(recipient, baseTokenAmount);
        }

        _collectQuoteToken(recipient);
    }

    /**
     * @dev Collects the quote token payout for an option
     * @param _recipient The address of the recipient of the payout
     */
    function _collectQuoteToken(address _recipient) internal {
        uint collectAmount;
        uint amount;

        for (uint i = 0; i < optionMakers[msg.sender].issuances.length; i++) {
            uint share = optionMakers[msg.sender].issuances[i].share;
            for (uint j = optionMakers[msg.sender].issuances[i].stageJoined; j < stageShare.length; j++) {
                amount = optionMakers[msg.sender].issuances[i].share.mul(stageShare[j]).div(10 ** decimals);
                optionMakers[msg.sender].issuances[i].share = optionMakers[msg.sender].issuances[i].share.sub(amount.mul(strikePriceDenominator).div(strikePriceRatio));
                collectAmount += amount;
            }
            optionMakers[msg.sender].issuances[i].share = share;

            collectAmount -= optionMakers[msg.sender].collected;
            IERC20(quoteToken).transfer(_recipient, collectAmount);
            optionMakers[msg.sender].collected += collectAmount;
        }
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
