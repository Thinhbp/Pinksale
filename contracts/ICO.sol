//SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.9;

interface ERC20Interface{
    //Mandatory functions
    function totalSupply() external view returns(uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function transfer(address to, uint tokens) external returns (bool success);

    function allowance(address tokenOwner, address spender) external view returns(uint remaning);
    function approve(address spender, uint tokens) external returns(bool success);
    function transferFrom(address from, address to, uint tokens) external returns(bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

/*
 ERC Token Standard #20 Interface
 https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
 + Scenario:
 - Founder of the token will deplpoy the token with his ETH account
 - After that his/her balance will be total supply of the token (check constructor function below)
 - Now founder will set allowance token to peopel by calling approve function
 - Now able to check how many tokens that that people have
 - Now people will be able to add the token in his wallet and withdraw the token from token owner account
 */
contract HMD is ERC20Interface{

    string public name = "Tom Hoang";
    string public symbol = "HMD";
    uint public  decimals = 0;
    uint public override totalSupply;

    address public founder; //the one who deploy the contract

    //store holders balance
    mapping(address => uint)  public balances;

    //How many tokens available that the onwer allow spender to withdraw
    mapping(address => mapping(address => uint)) public allowed;

    constructor(){
         totalSupply = 1000000;
         founder = msg.sender;
         balances[founder] = totalSupply;
    }

    /*
    Returns the balance of that address’s token holdings
    */
    function balanceOf(address tokenOwner) public view override returns (uint balance){
        return balances[tokenOwner];
    }

    /*
    Transfers tokens from one user to another
    */
    function transfer(address to, uint tokens) public virtual override returns (bool success) {
        require(balances[msg.sender] >= tokens,"Not enough tokens");

        balances[to] +=  tokens;
        balances[msg.sender] -= tokens;

        //Log event saved in blockchain
        emit Transfer(msg.sender, to, tokens);

        return true;
    }

    /*
    - Returns the remaining number of tokens
    that spender will be allowed to spend on behalf of owner through transferFrom.
    */
    function allowance(address tokenOwner, address spender) public view override returns(uint){
        return  allowed[tokenOwner][spender];
    }

    /*
    Sets amount as the allowance of spender over the caller’s tokens.
    */
    function approve(address spender, uint tokens) public override returns(bool success){
        require(balances[msg.sender] > tokens);
        require(tokens > 0);

        allowed[msg.sender][spender] = tokens;

        emit Approval(msg.sender, spender, tokens);

        return true;
    }

    /*
    Like transfer, it’s used to move tokens,
    but those tokens don’t necessarily need to belong to the person calling the contract.
    */
    function transferFrom(address from, address to, uint tokens) public virtual override returns(bool success){
        require(allowed[from][to] >= tokens);
        require(balances[from] > tokens);
        require(tokens > 0);

        balances[from] -= tokens;
        balances[to] += tokens;

        allowed[from][to] -= tokens;

        return true;
    }


}

/*
- WORKFLOW:
ICO is just a smart contract but just ETH in exchange for token owner named HMD
The token will be generated at the ICO time, meaning when running the ICO, the token will be created
There will be a deposit address(EOA account) that automatically receives the ETH sent to the ICO contract address(invest function)
Once investor sent ETH to ICO contract address, the token will be sending to investor account in return automatically

- USER STORIES:
As an investor, I want to send ETH to token's contract address and get the HMD token in return automatically
As an owner of the token, I want to set ICO's state
As an owner of the token, I want to stop the ICO just in case
As an onwer of the token, I want to set minumum and maximum invesment
As an onwer of the token, I want to know raised amount (number of ETH sent to my wallet)
As an onwer of the token, I want to set start trade date after sale end one week
*/
//Contract address: 0x0cEb40C5Db95937e96d98aD0A845223601536317
contract HMDICO is HMD{
    //Admin of ICO (token owner)
    address public admin;

    //Deposit address, will create a new account and use it as deposit address
    address payable public deposit;

    uint tokenPrice = 0.001 ether; //1 HMD = 0.001ETH or 1ETH = 1000HMD
    uint public hardCap = 300 ether; //Max amount

    uint public raisedAmount; //Total amount of ETH sent to ICO
    uint public saleStart = block.timestamp;
    uint public saleEnd = block.timestamp + 604800; //ICO ends in one week
    uint public tokenTradeStart = saleEnd + 604800; //transferable in a week after sale end

    uint public maxInvesment = 5 ether;
    uint public minInvesment = 0.1 ether;

    enum State {beforeStart, running, afterEnd, halted}
    State public icoState;

    constructor(address payable _deposit) {
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin,"Only admin is able to proceed");
        _;
    }
    //Admin able to halt the ico state
    function halt() public onlyAdmin{
        icoState = State.halted;
    }

    //Admin able to resume the icon state
    function resume() public onlyAdmin{
        icoState = State.running;
    }

    //Change deposit address, in case its get compromised
    function changeDepositAddress(address payable _newDeposit) public onlyAdmin{
        deposit = _newDeposit;
    }

    function getCurrentState() public view returns(State){
        if (icoState == State.halted){
            return State.halted;
        }else if(block.timestamp < saleStart) {
            return State.beforeStart;
        }else if (block.timestamp >= saleStart && block.timestamp <= saleEnd){
            return State.running;
        }else{
            return State.afterEnd;
        }
    }

    event Invest(address investor, uint value, uint tokens);

    /*
    The most imporant funciton.
    Investors will call it in receive function when sending ETH to the contract.
    From front-end (website) or when investors send directly.
    */
    function invest() public payable returns(bool){
        require(getCurrentState() == State.running);
        require(msg.value >= minInvesment && msg.value <= maxInvesment);
        raisedAmount += msg.value;
        require(raisedAmount <= hardCap);

        uint tokens = msg.value / tokenPrice;
        balances[msg.sender] += tokens;
        balances[founder] -= tokens;
        deposit.transfer(msg.value);

        emit Invest(msg.sender, msg.value, tokens);

        return true;
    }

    receive() external payable{
        //
        invest();
    }

    //Prevent price collapse:
    //So as an investor you will be transferable only if the current date is greater than tokenTradeStart
    function transfer(address to, uint tokens) public override returns (bool success) {
        require(block.timestamp > tokenTradeStart);
        super.transfer(to, tokens);

        return true;
    }

    function transferFrom(address from, address to, uint tokens) public override returns(bool success){
        require(block.timestamp > tokenTradeStart);
        super.transferFrom(from, to, tokens);

        return true;
    }

    /*
    Burn the tokens that have not beens sold in the ICO
    It is possible that the ICO has recived less than 300ETH, so where is the rest of the tokens?
    Of course in the token owner
    For transparency purposes, this function must be public, can execute by anyone
    */
    function burn() public returns(bool){
        require(getCurrentState() == State.afterEnd);

        balances[founder] = 0;

        return true;
    }
}
