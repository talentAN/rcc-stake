// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RccToken is ERC20 {
    constructor() ERC20("RccToken", "RCC") {
        // 初始供应量定义下，后续通过mint铸造
        _mint(msg.sender, 10000000 * 1_000_000_000_000_000_000); // 1,0
    }
}
