//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IOption {

    function baseToken() external view returns (address);

    function quoteToken() external view returns (address);
    
    function strikePriceRatio() external view returns (uint);
    
    function strikePriceDenominator() external view returns (uint);

    function balanceOf(address account) external view returns (uint256);


}