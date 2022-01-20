//SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

// The Cryptos Token Contract
contract Cryptos is IERC20{
    using SafeMath for uint256;

    string public name = "Cryptos";
    string public symbol = "CRPT";
    uint256 public decimals = 0;
    uint256 public override totalSupply;
    
    address public founder;

    mapping(address => uint256) public balances;    
    mapping(address => mapping(address => uint256)) allowed;
    
    constructor(){
        totalSupply = 1000000;
        founder = msg.sender;
        balances[founder] = totalSupply;
    } 
    
    function balanceOf(address _tokenOwner) public view override returns (uint256 balance){
        return balances[_tokenOwner];
    }

    function transfer(address _to, uint256 _tokens) public virtual override returns(bool success){
        require(balances[msg.sender] >= _tokens);
        
        balances[_to].add(_tokens);
        balances[msg.sender].sub(_tokens);

        emit Transfer(msg.sender, _to, _tokens);
        
        return true;
    }
    
    function allowance(address _tokenOwner, address _spender) public view override returns(uint256){
        return allowed[_tokenOwner][_spender];
    }
    
    function approve(address _spender, uint256 _tokens) public override returns (bool success){
        require(balances[msg.sender] >= _tokens);
        require(_tokens > 0);
        
        allowed[msg.sender][_spender] = _tokens;
        
        emit Approval(msg.sender, _spender, _tokens);

        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _tokens) public virtual override returns (bool success){
         require(allowed[_from][_to] >= _tokens);
         require(balances[_from] >= _tokens);
         
         balances[_from].sub(_tokens);
         balances[_to].add(_tokens);
         allowed[_from][_to].sub(_tokens);
         
         return true;
     }
}


contract CryptosICO is Cryptos{
    using SafeMath for uint256;

    address public admin;
    address payable public deposit;
    uint256 public hardCap = 300 ether;
    uint256 public raisedAmount; 
    uint256 public saleStart = block.timestamp;
    uint256 public saleEnd = block.timestamp.add(604800); //one week
    uint256 public tokenTradeStart = saleEnd.add(604800); //transferable in a week after saleEnd
    uint256 public maxInvestment = 5 ether;
    uint256 public minInvestment = 0.1 ether;
    uint256 tokenPrice = 0.001 ether;  

    event Invest(address investor, uint256 value, uint256 tokens);

    modifier onlyAdmin(){
        require(msg.sender == admin);
        _;
    }
    
    enum State { beforeStart, running, afterEnd, halted} // ICO states 
    State public icoState;
    
    constructor(address payable _deposit){
        deposit = _deposit; 
        admin = msg.sender; 
        icoState = State.beforeStart;
    }
       
    receive () payable external{
        invest();
    }
        
    // emergency stop
    function halt() public onlyAdmin{
        icoState = State.halted;
    }
    
    function resume() public onlyAdmin{
        icoState = State.running;
    }
    
    function changeDepositAddress(address payable _newDeposit) public onlyAdmin{
        deposit = _newDeposit;
    }
    
    function getCurrentState() public view returns(State){
        if(icoState == State.halted){
            return State.halted;
        }else if(block.timestamp < saleStart){
            return State.beforeStart;
        }else if(block.timestamp >= saleStart && block.timestamp <= saleEnd){
            return State.running;
        }else{
            return State.afterEnd;
        }
    }
    
    // function called when sending eth to the contract
    function invest() payable public returns(bool){ 
        icoState = getCurrentState();
        require(icoState == State.running);
        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        
        raisedAmount += msg.value;
        require(raisedAmount <= hardCap);
        
        uint256 tokens = msg.value / tokenPrice;

        // adding tokens to the inverstor's balance from the founder's balance
        balances[msg.sender].add(tokens);
        balances[founder].sub(tokens); 
        deposit.transfer(msg.value); // transfering the value sent to the ICO to the deposit address
        
        emit Invest(msg.sender, msg.value, tokens);
        
        return true;
    }
    
    // burning unsold tokens
    function burn() public returns(bool){
        icoState = getCurrentState();
        require(icoState == State.afterEnd);
        balances[founder] = 0;
        return true;
    }
    
    function transfer(address _to, uint256 _tokens) public override returns (bool success){
        require(block.timestamp > tokenTradeStart); // the token will be transferable only after tokenTradeStart
        
        // calling the transfer function of the base contract
        super.transfer(_to, _tokens);  // same as Cryptos.transfer(to, tokens);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _tokens) public override returns (bool success){
        require(block.timestamp > tokenTradeStart); // the token will be transferable only after tokenTradeStart
       
        Cryptos.transferFrom(_from, _to, _tokens);  // same as super.transferFrom(to, tokens);
        return true;
    }
}
