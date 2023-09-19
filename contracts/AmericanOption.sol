//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/src/utils/ReentrancyGuard.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";

contract AmericanOption is ERC20, ReentrancyGuard {
    struct IssueInfo {
        uint share;
        uint32 stageJoined;
    }

    struct OptionMaker {
        uint totalShare;
        uint collected;
        IssueInfo[] issuances;
    }

    using SafeMath for uint256;

    uint[] stageShare;

    address public immutable baseToken;
    address public immutable quoteToken;
    uint public immutable strikePriceRatio;
    uint public immutable expirationDate;

    uint totalShare;

    IPermit2 public immutable permit2;
    address public broker;
    uint256 strikePriceDenominator;

    mapping(address => OptionMaker) public optionMakers;

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
    ) ERC20("AmericanOption", "EOPT", _baseTokenDecimals) {
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
    ) external nonReentrant onlyBroker {
        require(amount != 0, "ERROR: optionAmount cannot be zero");

        permit2.transferFrom(maker, address(this), uint160(amount), baseToken);

        _mint(taker, amount);
        totalShare += amount;

        optionMakers[maker].totalShare += amount;

        optionMakers[maker].issuances.push(
            IssueInfo(amount, uint32(stageShare.length))
        );
    }

    function exercise(
        address owner,
        uint amount,
        IPermit2.PermitSingle memory permitSingle,
        bytes memory signature
    ) external nonReentrant isNotExpierd {
        _burn(owner, amount);
        IERC20(baseToken).transfer(owner, amount);

        amount = amount.mul(strikePriceRatio).div(strikePriceDenominator);
        uint256 userAllowance = IERC20(quoteToken).allowance(
            owner,
            address(this)
        );
        if (amount >= userAllowance)
            permit2.permit(owner, permitSingle, signature);

        permit2.transferFrom(owner, address(this), uint160(amount), quoteToken);
        stageShare.push(amount.mul(10 ** decimals).div(totalSupply));
    }

    function collect(address recipient) external nonReentrant isExpierd {
        uint baseTokenAmount = totalSupply
            .mul(optionMakers[msg.sender].totalShare)
            .div(totalShare);
        IERC20(baseToken).transfer(recipient, baseTokenAmount);

        _collectQuoteToken(recipient);
    }

    function _collectQuoteToken(address _recipient) internal {
        uint collectAmount;

        for (uint i = 0; i < optionMakers[msg.sender].issuances.length; i++) {
            for (
                uint j = optionMakers[msg.sender].issuances[i].stageJoined;
                j < stageShare.length;
                j++
            ) {
                collectAmount += optionMakers[msg.sender]
                    .issuances[i]
                    .share
                    .mul(stageShare[j])
                    .div(10 ** decimals);
                optionMakers[msg.sender].issuances[i].share = optionMakers[
                    msg.sender
                ].issuances[i].share.sub(
                        collectAmount.mul(strikePriceDenominator).div(
                            strikePriceRatio
                        )
                    );
            }

            collectAmount -= optionMakers[msg.sender].collected;
            IERC20(quoteToken).transfer(_recipient, collectAmount);
            optionMakers[msg.sender].collected += collectAmount;
        }
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
