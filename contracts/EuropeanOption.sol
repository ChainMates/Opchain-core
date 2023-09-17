//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";

contract EuropeanOption is ERC20 {
    struct Order {
        address owner;
        uint amount;
        IPermit2.Pemit2 permit;
    }

    using SafeMath for uint256;

    string PERMIT2_ORDER_TYPE = "";

    address public immutable baseToken;
    address public immutable quoteToken;
    uint public immutable strikePriceBaseTokenRatio;
    uint public immutable strikePriceQuoteTokenRatio;
    uint public immutable expirationDate;

    uint totalShare;

    bool private _reentrancyGuard;
    IPermit2 public immutable permit2;

    mapping(address => uint) public makersShare;

    // Prevents reentrancy attacks via tokens with callback mechanisms.
    modifier nonReentrant() {
        require(!_reentrancyGuard, "no reentrancy");
        _reentrancyGuard = true;
        _;
        _reentrancyGuard = false;
    }

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
    
    constructor(
        address _baseToken,
        address _quoteToken,
        uint _strikePriceBaseTokenRatio,
        uint _strikePriceQuoteTokenRatio,
        uint _expirationDate,
        uint8 _baseTokenDecimals,
        IPermit2 _permit2
    ) ERC20("EuropeanOption", "EOPT", _baseTokenDecimals) {
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        strikePriceBaseTokenRatio = _strikePriceBaseTokenRatio;
        strikePriceQuoteTokenRatio = _strikePriceQuoteTokenRatio;
        expirationDate = _expirationDate;
        permit2 = _permit2;
    }


    function issue(Order memory order, address taker) external isNotExpierd nonReentrant {

        require(order.amount != 0, "ERROR: optionAmount cannot be zero");

        _transferTokens(order);
        _mint(taker, order.amount);
        totalShare += order.amount;
        makersShare[order.owner] += order.amount;
    }

    function exercise(Order memory order) external nonReentrant isExercisable isNotExpierd {

        IERC20(baseToken).transfer(order.owner, order.amount);
        _burn(order.owner, order.amount);

        order.amount = order.amount.mul(strikePriceQuoteTokenRatio).div(
            strikePriceBaseTokenRatio
        );
        _transferTokens(order);
        

    }

    function collect(address recipient) external nonReentrant isExpierd {
        uint baseTokenAmount = totalSupply.mul(makersShare[msg.sender]).div(
            totalShare
        );
        IERC20(baseToken).transfer(recipient, baseTokenAmount);

        uint quoteTokenAmount = (
            totalShare.sub(totalSupply).mul(strikePriceQuoteTokenRatio).div(
                strikePriceBaseTokenRatio
            )
        ).mul(makersShare[msg.sender]).div(totalShare);
        IERC20(baseToken).transfer(recipient, quoteTokenAmount);
    }

    function _transferTokens(Order memory order) internal {
        // Transfer tokens from the caller to ourselves.
        permit2.permitWitnessTransferFrom(
            // The permit message.
            IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({
                    token: order.permit.token,
                    amount: order.permit.amount
                }),
                nonce: order.permit.nonce,
                deadline: order.permit.deadline
            }),
            // The transfer recipient and amount.
            IPermit2.SignatureTransferDetails({
                to: address(this),
                requestedAmount: order.amount
            }),
            // The owner of the tokens, which must also be
            // the signer of the message, otherwise this call
            // will fail.
            order.owner,
            order.permit.hash,
            PERMIT2_ORDER_TYPE,
            // The packed signature that was the result of signing
            // the EIP712 hash of `permit`.
            order.permit.signature
        );
    }
}
