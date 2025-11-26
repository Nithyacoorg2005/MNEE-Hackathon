// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MNEE_Mock_Token is ERC20 {
    constructor() ERC20("MNEE Stablecoin Mock", "MNEE") {
        _mint(msg.sender, 1000000 * 10**decimals()); // 1 Million MNEE initial supply
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}