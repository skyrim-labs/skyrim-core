// SPDX-License-Identifier: MIT

/**
 *Submitted for verification at Etherscan.io on 2018-05-21
*/

pragma solidity >=0.7.0 <0.8.0;

import "../library/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

////////////////////////////////////////////////////////////////////////////////

/*
 * ERC20Basic
 * Simpler version of ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
interface ERC20Basic {
    function balanceOf(address who) external view returns (uint);
    function transfer(address to, uint value) external returns(bool);
    event Transfer(address indexed from, address indexed to, uint value);
}

////////////////////////////////////////////////////////////////////////////////

/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
interface ERC20 is ERC20Basic {
    function allowance(address owner, address spender) external view returns (uint);
    function transferFrom(address from, address to, uint value) external returns(bool);
    function approve(address spender, uint value) external returns(bool);
    event Approval(address indexed owner, address indexed spender, uint value);
}

////////////////////////////////////////////////////////////////////////////////

/*
 * Basic token
 * Basic version of StandardToken, with no allowances
 */
contract BasicToken is ERC20Basic {
    using SafeMathUpgradeable for uint;

    mapping(address => uint) balances;

    /*
     * Fix for the ERC20 short address attack
     */
    modifier onlyPayloadSize(uint size) {
        if (msg.data.length < size + 4) {
         revert();
        }
        _;
    }

    function transfer(address _to, uint _value) override public onlyPayloadSize(2 * 32) returns(bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) override public view returns (uint balance) {
      return balances[_owner];
    }
}


////////////////////////////////////////////////////////////////////////////////

/**
 * Standard ERC20 token
 *
 * https://github.com/ethereum/EIPs/issues/20
 * Based on code by FirstBlood:
 * https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is BasicToken, ERC20 {
    using SafeMathUpgradeable for uint;

    mapping (address => mapping (address => uint)) allowed;

    function transferFrom(address _from, address _to, uint _value) override public returns(bool) {

        uint _allowance = allowed[_from][msg.sender];

        // Check is not needed because sub(_allowance, _value) will already revert if this condition is not met
        if (_value > _allowance) revert();

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);

        emit Transfer(_from, _to, _value);

        return true;
    }

    function approve(address _spender, uint _value) override public returns(bool){
        allowed[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);

        return true;
    }

    function allowance(address _owner, address _spender) override public view returns (uint remaining) {
        return allowed[_owner][_spender];
    }
}

////////////////////////////////////////////////////////////////////////////////

/*
 * SimpleToken
 *
 * Very simple ERC20 Token example, where all tokens are pre-assigned
 * to the creator. Note they can later distribute these tokens
 * as they wish using `transfer` and other `StandardToken` functions.
 */
contract DAIOLD is StandardToken {
    using SafeMathUpgradeable for uint;

    uint private totalSupply;
    string public name = "Test";
    string public symbol = "TST";
    uint public decimals = 18;
    uint public INITIAL_SUPPLY = 10**(50+18);

    constructor(string memory _name, string memory _symbol, uint _decimals) payable {
        totalSupply = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    event Burn(address indexed _burner, uint _value);

    function burn(uint _value) public returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);

        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, address(0x0), _value);

        return true;
    }

    // save some gas by making only one contract call
    function burnFrom(address _from, uint256 _value) public returns (bool) {
        transferFrom( _from, msg.sender, _value );
        return burn(_value);
    }
}