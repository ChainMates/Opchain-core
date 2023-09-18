//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {IERC20} from "./interface/IERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";

contract EuropeanOption is ERC20 {

    struct Order {
        address owner;
        uint256 amount;
        bytes signature;
        IPermit2.PermitSingle permitSingle;
    }

    using SafeMath for uint256;

    string PERMIT2_ORDER_TYPE = "";

    address public immutable baseToken;
    address public immutable quoteToken;
    uint public immutable strikePriceRatio;
    uint public immutable expirationDate;

    uint totalShare;

    bool private _reentrancyGuard;
    IPermit2 public immutable permit2;
    address public broker;
    uint256 strikePriceDenominator;

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
        IPermit2 _permit2 ,
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


    function issue(Order memory order, address taker) external isNotExpierd nonReentrant onlyBroker {

        require(order.amount != 0, "ERROR: optionAmount cannot be zero");

        permitAndTransfer(order);
        _mint(taker, order.amount);
        totalShare += order.amount;
        makersShare[order.owner] += order.amount;
    }

    function exercise(Order memory order) external nonReentrant isExercisable isNotExpierd {

        IERC20(baseToken).transfer(order.owner, order.amount);
        _burn(order.owner, order.amount);

        order.amount = order.amount.mul(strikePriceRatio).div(
            strikePriceDenominator
        );
        permitAndTransfer(order);
        

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
