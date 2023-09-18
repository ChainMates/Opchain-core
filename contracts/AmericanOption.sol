//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";

contract AmericanOption is ERC20 {
    struct IssueInfo {
        uint share;
        uint32 stageJoined;
    }

    struct OptionMaker {
        uint totalShare;
        uint collected;
        IssueInfo[] issuances;
    }

    struct Order {
        address owner;
        uint256 amount;
        bytes signature;
        IPermit2.PermitSingle permitSingle;
    }

    using SafeMath for uint256;

    string PERMIT2_ORDER_TYPE = "";

    uint[] stageShare;

    address public immutable baseToken;
    address public immutable quoteToken;
    uint public immutable strikePriceRatio;
    uint public immutable expirationDate;

    uint totalShare;

    bool private _reentrancyGuard;
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

    // Prevents reentrancy attacks via tokens with callback mechanisms.
    modifier nonReentrant() {
        require(!_reentrancyGuard, "no reentrancy");
        _reentrancyGuard = true;
        _;
        _reentrancyGuard = false;
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
        broker =_broker;
        strikePriceDenominator = 10 ** _baseTokenDecimals;
    }


    function issue(Order memory order, address taker) external nonReentrant onlyBroker {
        require(order.amount != 0, "ERROR: optionAmount cannot be zero");

        permitAndTransfer(order);

        _mint(taker, order.amount);
        totalShare += order.amount;

        optionMakers[order.owner].totalShare += order.amount;

        optionMakers[order.owner].issuances.push(
            IssueInfo(order.amount, uint32(stageShare.length))
        );
    }

    function exercise(Order memory order) external nonReentrant {
        _burn(order.owner, order.amount);
        IERC20(baseToken).transfer(order.owner, order.amount);

        order.amount = order.amount.mul(strikePriceRatio).div(
            strikePriceDenominator
        );
        permitAndTransfer(order);
        stageShare.push(order.amount.mul(10 ** decimals).div(totalSupply));
    }

    function collectQuoteToken(address recipient) external nonReentrant {
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
            IERC20(quoteToken).transfer(recipient, collectAmount);
            optionMakers[msg.sender].collected += collectAmount;
        }
    }

    function collect(address recipient) external nonReentrant isExpierd {
        uint baseTokenAmount = totalSupply
            .mul(optionMakers[msg.sender].totalShare)
            .div(totalShare);
        IERC20(baseToken).transfer(recipient, baseTokenAmount);
    }

    // function permitAndTransfer(Order memory order) internal {
    //     // Transfer tokens from the caller to ourselves.
    //     permit2.permitWitnessTransferFrom(
    //         // The permit message.
    //         IPermit2.PermitTransferFrom({
    //             permitted: IPermit2.TokenPermissions({
    //                 token: order.permit.token,
    //                 amount: order.permit.amount
    //             }),
    //             nonce: order.permit.nonce,
    //             deadline: order.permit.deadline
    //         }),
    //         // The transfer recipient and amount.
    //         IPermit2.SignatureTransferDetails({
    //             to: address(this),
    //             requestedAmount: order.amount
    //         }),
    //         // The owner of the tokens, which must also be
    //         // the signer of the message, otherwise this call
    //         // will fail.
    //         order.owner,
    //         order.permit.hash,
    //         PERMIT2_ORDER_TYPE,
    //         // The packed signature that was the result of signing
    //         // the EIP712 hash of `permit`.
    //         order.permit.signature
    //     );
    // }


    function permitAndTransfer(Order memory order) internal {
   
    require(order.permitSingle.spender != address(this) , "ERROR: invalid spender");
    permit2.permit(msg.sender, order.permitSingle, order.signature);
    permit2.transferFrom(msg.sender, address(this), uint160(order.amount) , order.permitSingle.details.token);
    //...Do cooler stuff ...
   }
}
