pragma solidity 0.4.25;


interface ERC223EthFee {
    function transfer(address _to, uint256 _value, bytes _data) public payable returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);
}
