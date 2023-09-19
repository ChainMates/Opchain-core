//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPermit2} from "./IPermit2.sol";

interface IOption {
    function baseToken() external view returns (address);

    function quoteToken() external view returns (address);

    function strikePriceRatio() external view returns (uint);

    function strikePriceDenominator() external view returns (uint);

    function issue(address maker, address taker, uint amount) external;

    function exercise(
        address owner,
        uint amount,
        IPermit2.PermitSingle memory permitSingle,
        bytes memory signature
    ) external;

    function brokerSwap(address maker, address taker, uint amount) external;
}
