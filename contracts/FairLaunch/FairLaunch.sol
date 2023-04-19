// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
//import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


import "../structs/FairLaunch.sol";
import "../interfaces/IGSLock.sol";
import "../interfaces/IGSERC20.sol";


contract FairLaunch is Ownable, Pausable {
    //using SafeMath for uint256;
    using SafeERC20 for IGSERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private whiteListUsers;
    EnumerableSet.AddressSet private superAccounts;


    modifier onlyWhiteListUser() {
        require(whiteListUsers.contains(msg.sender), "Only Admin");
        _;
    }

    modifier onlySuperAccount() {
        require(superAccounts.contains(msg.sender), "Only Super");
        _;
    }

    modifier onlyRunningPool() {
        require(state == 1, "Not available pool");
        _;
    }



    function addWhiteListUsers(address[] memory _user) public onlyWhiteListUser {
        for (uint i = 0; i < _user.length; i++) {
            whiteListUsers.add(_user[i]);
        }
    }


    function removeWhiteListUsers(address[] memory _user) public onlyWhiteListUser {
        for (uint i = 0; i < _user.length; i++) {
            whiteListUsers.remove(_user[i]);
         }
    }

    function listOfWhiteListUsers() public view returns(address[] memory) {
        return whiteListUsers.values();
    }


   function _check(address _tokenA, address _tokenB, address _routerAddress, address _factoryAddress) internal view returns (bool) {

        address pair;
        IUniswapV2Router02 routerObj = IUniswapV2Router02(_routerAddress);
        IUniswapV2Factory factoryObj = IUniswapV2Factory(_factoryAddress);

        if (_tokenB == address(0)) {
            pair = factoryObj.getPair(address(_tokenA), routerObj.WETH());
        } else {
            pair = factoryObj.getPair(address(_tokenA), address(_tokenB));
        }
        if (pair == address(0)) {
            return true;
        }
        return IGSERC20(pair).totalSupply() == 0;

    }
    function check() external view returns (bool) {
        return _check(address(icoToken), feeToken, routerAddress, factoryAddress);
    }

    IGSERC20 public icoToken;
    address public feeToken; //BUSD, BNB
    uint256 public softCap;

    uint256 public maxInvest;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public currentPrice = 0;

    bool public affiliate; 
    uint256 public percertAffiliate;
    uint256 public affiliateReward;



    uint256 public state; // 1 running||available, 2 finalize, 3 cancel
    uint256 public raisedAmount; 
    address public signer;
    uint256 public constant ZOOM = 10_000;
    uint256 public penaltyFee = 1000;

    // dex
    // bool public manualListing;
    address public factoryAddress;
    address public routerAddress;
    //uint256 public listingPrice;
    uint256 public listingPercent = 0; //1 => 10000
    uint256 public lpLockTime; //seconds

    IGSLock public gsLock;
    uint256 public lpLockId;
    uint256 public teamLockId;

    //fee
    uint256 public raisedFeePercent; //BNB With Raised Amount
    uint256 public raisedTokenFeePercent;

    address payable public fundAddress;
    //uint256 public totalSoldTokens;

    address public deadAddress = address(0x0000dead);
    uint256 public totalRaise = 0;


    struct JoinInfo {
        uint256 totalInvestment;
        //uint256 claimedTokens;
        uint256 totalTokens;
        //bool refund;
    }

    mapping(address => JoinInfo) public joinInfos;
    EnumerableSet.AddressSet private _joinedUsers; // set of joined users



    event Invest(address investor, uint value, uint tokens);
    event Buy(uint256 indexed _saleId, uint256 indexed _quantity, uint256 indexed _price, address _buyer, address _seller);
    event UpdateSaleQuantity(uint256 indexed _saleId, address indexed _seller, uint256 indexed _quantity, uint256 _status);
    event UpdateSalePrice(uint256 indexed _saleId, address indexed _seller, uint256 indexed _price);
    event CancelListed(uint256 indexed _saleId, address indexed _receiver);
    event List(uint indexed _saleId, uint256 indexed _price, uint256 indexed _quantity, address _owner, uint256 _tokenId, uint256 status);
    event TokenClaimed(address _address, uint256 tokensClaimed);


    function setFundAddress(address payable _fundAddress) public onlySuperAccount {
        fundAddress = _fundAddress;
    }

    function setSigner(address _signer) public onlySuperAccount {
        signer = _signer;
    }

    function setPenaltyFee(uint256 _penaltyFee) public onlySuperAccount {
        penaltyFee = _penaltyFee;
    }


    function setDex(address _factory, address _router) public onlySuperAccount {
        factoryAddress = _factory;
        routerAddress = _router;
    }
    bool public isMaxinvest;

    constructor(LaunchpadStructs.LaunchpadInfo memory info,LaunchpadStructs.DexInfo memory dexInfo, LaunchpadStructs.FeeSystem memory feeInfo, LaunchpadStructs.SettingAccount memory settingAccount,uint256 _percertAffiliate) {

        require(info.icoToken != address(0), 'TOKEN');
        //require(info.presaleRate > 0, 'PRESALE');
        require(info.softCap >0, 'CAP');
        require(info.startTime < info.endTime, 'TIME');
        isMaxinvest = info.isMaxinvest;
        if (info.isMaxinvest) {
            require(info.maxInvest > 0, 'INVEST');
        }
        
        require(dexInfo.listingPercent <= ZOOM, 'LISTING');
        if (info.feeToken == address(0)) { //Auto listing
            listingPercent = dexInfo.listingPercent;
            require(_check(info.icoToken, info.feeToken, dexInfo.routerAddress, dexInfo.factoryAddress), 'LP Added!');
        }


        totalRaise = info.totalIcoToken;
        icoToken = IGSERC20(info.icoToken);
        feeToken = info.feeToken;
        softCap = info.softCap;
        
   
        maxInvest = info.maxInvest;
        startTime = info.startTime;
        endTime = info.endTime;

        percertAffiliate = _percertAffiliate;
        affiliate = info.affiliate;



        raisedFeePercent = feeInfo.raisedFeePercent;
        raisedTokenFeePercent = feeInfo.raisedTokenFeePercent;
        penaltyFee = feeInfo.penaltyFee;


        state = 1;
        whiteListUsers.add(settingAccount.deployer);
        whiteListUsers.add(settingAccount.superAccount);
        superAccounts.add(settingAccount.superAccount);

        signer = settingAccount.signer;
        fundAddress = settingAccount.fundAddress;
        transferOwnership(settingAccount.deployer);
        gsLock = IGSLock(settingAccount.gsLock);
    }

    mapping(address => uint256) public award;
    uint256 totalReferred = 0;

    function setAffiliate(uint256 _percent) public onlyWhiteListUser {
        require(block.timestamp <= endTime, "Invalid Time");
        require(state == 1, "Can not  update affiliate");
        require(_percent >= 100 && _percent <= 1000, "Invalid percent");
        affiliate = true;
        percertAffiliate = _percent;
    }



    // function contribute(uint256 _amount, bytes calldata _sig) external payable whenNotPaused onlyRunningPool {
    function contribute(uint256 _amount, address _presenter) external payable whenNotPaused onlyRunningPool {
        require(startTime <= block.timestamp && endTime >= block.timestamp, 'Invalid time');
        require(_presenter != _msgSender(), "Invalid presenter");

        JoinInfo storage joinInfo = joinInfos[_msgSender()];
        if (isMaxinvest) {
            require(joinInfo.totalInvestment+(_amount) <= maxInvest, 'Invalid amount');
        }

        uint256 feeTokenDecimals = 18;
        uint256 feeRaisedTokenDecimals = icoToken.decimals();
        if (feeToken != address(0)) {
            feeTokenDecimals = IGSERC20(feeToken).decimals();
        }

        joinInfo.totalInvestment = joinInfo.totalInvestment+(_amount);

        // uint256 newTotalSoldTokens = calculateUserTotalTokens(_amount);
        // totalSoldTokens = totalSoldTokens+(newTotalSoldTokens);
        // joinInfo.totalTokens = joinInfo.totalTokens+(newTotalSoldTokens);
        // joinInfo.refund = false;

        raisedAmount = raisedAmount+(_amount);
        currentPrice = (totalRaise * 10 **(18 - feeRaisedTokenDecimals)) / (raisedAmount * 10 ** (18 - feeTokenDecimals));
        _joinedUsers.add(_msgSender());


        if (feeToken == address(0)) {
            require(msg.value >= _amount, 'Invalid Amount');
        } else {
            IGSERC20 feeTokenErc20 = IGSERC20(feeToken);
            feeTokenErc20.safeTransferFrom(_msgSender(), address(this), _amount);
        }
        if ((_presenter != address(0)) && (affiliate)){
            award[_presenter] += _amount;
            totalReferred += _amount;
        }
    }


    function cancelLaunchpad() external onlyWhiteListUser onlyRunningPool {
        state = 3;
    }

    // function setClaimTime(uint256 _listingTime) external onlyWhiteListUser {
    //     require(state == 2 && _listingTime > 0, "TIME");
    //     listingTime = _listingTime;
    // }


    // function setWhitelistPool(uint256 _wlPool, address _holdingToken, uint256 _amount) external onlyWhiteListUser {
    //     require(_wlPool < 2 ||
    //         (_wlPool == 2 && _holdingToken != address(0) && IGSERC20(_holdingToken).totalSupply() > 0 && _amount > 0), 'Invalid setting');
    //     holdingToken = _holdingToken;
    //     holdingTokenAmount = _amount;
    //     whitelistPool = _wlPool;
    // }

    function finalizeLaunchpad() external onlyWhiteListUser onlyRunningPool {
        require(block.timestamp > startTime, 'Not start');


        if (block.timestamp >= endTime) {
            require(raisedAmount >= softCap, 'Not meet soft cap');
        }
        state = 2;
        affiliateReward = raisedAmount * percertAffiliate / (ZOOM);

        uint256 feeTokenDecimals = 18;
        uint256 feeRaisedTokenDecimals = icoToken.decimals();
        if (feeToken != address(0)) {
            feeTokenDecimals = IGSERC20(feeToken).decimals();
        }
      
        uint256 icoTokenToAddLP = totalRaise * (ZOOM - raisedFeePercent)* listingPercent / (ZOOM **2);

        uint256 totalFeeTokensToAddLP = (icoTokenToAddLP * 10 ** (18 - feeRaisedTokenDecimals) / currentPrice) / (10**(18 - feeTokenDecimals));
        uint256 totalRaisedFeeTokens = totalRaise * raisedTokenFeePercent / ZOOM;
        uint256 totalRaisedFee = raisedAmount * raisedFeePercent / ZOOM;
        if (totalRaisedFeeTokens > 0) {
            icoToken.safeTransfer(fundAddress, totalRaisedFeeTokens);
        }
        if (totalRaisedFee > 0) {
            if (feeToken == address(0)) {
                payable(fundAddress).transfer(totalRaisedFee);
            } else {
                IGSERC20(feeToken).safeTransfer(fundAddress, totalRaisedFee);
            }
        }
        uint256 raisedAmountToOwner = raisedAmount - affiliateReward - totalRaisedFee -  totalFeeTokensToAddLP; 

        if (raisedAmountToOwner > 0) {
            if (feeToken == address(0)) {
                payable(owner()).transfer(raisedAmountToOwner);
            } else {
                IGSERC20(feeToken).safeTransfer(owner(), raisedAmountToOwner);
            }
        }

        if (feeToken == address(0)) {
            icoToken.approve(routerAddress, icoTokenToAddLP);
            require(_check(address(icoToken), feeToken, routerAddress, factoryAddress), 'LP Added!');
            IUniswapV2Router02 routerObj = IUniswapV2Router02(routerAddress);
            IUniswapV2Factory factoryObj = IUniswapV2Factory(factoryAddress);
            address pair;
            uint liquidity;
            (,, liquidity) = routerObj.addLiquidityETH{value : totalFeeTokensToAddLP}(
                address(icoToken),
                icoTokenToAddLP,
                0,
                0,
                address(this),
                block.timestamp);
            pair = factoryObj.getPair(address(icoToken), routerObj.WETH());

            require(pair != address(0), 'Invalid pair');
            require(liquidity > 0, 'Invalid Liquidity!');
             if (lpLockTime > 0) {
                IGSERC20(pair).approve(address(gsLock), liquidity);
                uint256 unlockDate = block.timestamp + lpLockTime;
                lpLockId = gsLock.lock(owner(), pair, true, liquidity, unlockDate, 'LP');

            } else {
                IGSERC20(pair).safeTransfer(owner(), liquidity);
            }

        } 
    }

    function claimCommission() public {
        require(state == 2 && award[_msgSender()] >0 ,"You can not claim awards");
        //require(affiliate, "Launchpad doesn't include affiliate program");
        uint256 amount = award[_msgSender()] *  affiliateReward / totalReferred;
        award[_msgSender()] = 0;
        if (feeToken == address(0)) {
            payable(_msgSender()).transfer(amount);
        }
        else {
            IGSERC20 token = IGSERC20(feeToken);
            token.safeTransfer(_msgSender(), amount);
        }
    }

    function claimCanceledTokens() external onlyWhiteListUser {
        require(state == 3, 'Not cancel');
        uint256 balance = icoToken.balanceOf(address(this));
        require(balance > 0, "Claimed");
        if (balance > 0) {
            icoToken.safeTransfer(_msgSender(), balance);
        }
    }

    function emergencyWithdrawPool(address _token, uint256 _amount) external onlySuperAccount {
        require(_amount > 0, 'Invalid amount');
        if (_token == address(0)) {
            payable(_msgSender()).transfer(_amount);
        }
        else {
            IGSERC20 token = IGSERC20(_token);
            token.safeTransfer(_msgSender(), _amount);
        }
    }


    function withdrawContribute() external whenNotPaused {
        JoinInfo storage joinInfo = joinInfos[_msgSender()];
        require((state == 3) || (raisedAmount < softCap && block.timestamp > endTime));
        //require(joinInfo.refund == false, 'Refunded');
        require(joinInfo.totalInvestment > 0, 'Not Invest');

        uint256 totalWithdraw = joinInfo.totalInvestment;
        //joinInfo.refund = true;
        joinInfo.totalTokens = 0;
        joinInfo.totalInvestment = 0;

        raisedAmount = raisedAmount-(totalWithdraw);

        //totalSoldTokens = totalSoldTokens-(joinInfo.totalTokens);

        _joinedUsers.remove(_msgSender());

        if (feeToken == address(0)) {
            require(address(this).balance > 0, 'Insufficient blc');
            payable(_msgSender()).transfer(totalWithdraw);
        } else {
            IGSERC20 feeTokenErc20 = IGSERC20(feeToken);

            require(feeTokenErc20.balanceOf(address(this)) >= totalWithdraw, 'Insufficient Balance');
            feeTokenErc20.safeTransfer(_msgSender(), totalWithdraw);
        }
    }

    function emergencyWithdrawContribute() external whenNotPaused onlyRunningPool {
        JoinInfo storage joinInfo = joinInfos[_msgSender()];
        require(startTime <= block.timestamp && endTime >= block.timestamp, 'Invalid time');
        //require(joinInfo.refund == false, 'Refunded');
        require(joinInfo.totalInvestment > 0, 'Not contribute');

        uint256 penalty = joinInfo.totalInvestment*(penaltyFee)/(ZOOM);
        uint256 refundTokens = joinInfo.totalInvestment-(penalty);
        raisedAmount = raisedAmount-(joinInfo.totalInvestment);
        //totalSoldTokens = totalSoldTokens-(joinInfo.totalTokens);


        //joinInfo.refund = true;
        joinInfo.totalTokens = 0;
        joinInfo.totalInvestment = 0;
        _joinedUsers.remove(_msgSender());

        require(refundTokens > 0, 'Invalid rf amount');

        if (feeToken == address(0)) {
            if (refundTokens > 0) {
                payable(_msgSender()).transfer(refundTokens);
            }

            if (penalty > 0) {
                payable(fundAddress).transfer(penalty);
            }

        } else {
            IGSERC20 feeTokenErc20 = IGSERC20(feeToken);
            if (refundTokens > 0) {
                feeTokenErc20.safeTransfer(_msgSender(), refundTokens);
            }

            if (penalty > 0) {
                feeTokenErc20.safeTransfer(fundAddress, penalty);
            }
        }
    }


    function claimTokens() external whenNotPaused {
        JoinInfo storage joinInfo = joinInfos[_msgSender()];
        require(state == 2, "Not finalize");

        uint256 claimableTokens = _getUserClaimAble(joinInfo);
        require(claimableTokens > 0, 'Zero token');
        joinInfo.totalInvestment = 0;

        joinInfo.totalTokens = claimableTokens;
        icoToken.safeTransfer(_msgSender(), claimableTokens);
        
    }

    function getUserClaimAble(address _sender) external view returns (uint256) {
        JoinInfo storage joinInfo = joinInfos[_sender];
        return _getUserClaimAble(joinInfo);
    }

    function _getUserClaimAble(JoinInfo memory joinInfo)
    internal
    view
    returns (uint256)
    {
        uint256 claimableTokens = 0;
        uint256 feeTokenDecimals = 18;
        uint256 feeRaisedTokenDecimals = icoToken.decimals();
        if (feeToken != address(0)) {
            feeTokenDecimals = IGSERC20(feeToken).decimals();
        }
        if (state != 2) {
            claimableTokens = 0;
        } else {
            claimableTokens =  feeTokenDecimals >= feeRaisedTokenDecimals ? joinInfo.totalInvestment / (10 ** (feeTokenDecimals - feeRaisedTokenDecimals)) * currentPrice : joinInfo.totalInvestment * (10 ** (feeRaisedTokenDecimals-feeTokenDecimals)) * currentPrice;
        }
        
        return claimableTokens;
    }


    function getLaunchpadInfo() external view returns (LaunchpadStructs.LaunchpadReturnInfo memory) {
        uint256 balance = icoToken.balanceOf(address(this));

        LaunchpadStructs.LaunchpadReturnInfo memory result;
        result.softCap = softCap;
        result.totalIcoToken = totalRaise;
        result.startTime = startTime;
        result.endTime = endTime;
        result.state = state;
        result.raisedAmount = raisedAmount;
        result.balance = balance;
        result.feeToken = feeToken;

        return result;
    }

    


    function getJoinedUsers()
    external
    view
    returns (address[] memory)
    {
        uint256 start = 0;
        uint256 end = _joinedUsers.length();
        if (end == 0) {
            return new address[](0);
        }
        uint256 length = end - start;
        address[] memory result = new address[](length);
        uint256 index = 0;
        for (uint256 i = start; i < end; i++) {
            result[index] = _joinedUsers.at(i);
            index++;
        }
        return result;
    }


    function pause() public onlyWhiteListUser whenNotPaused {
        _pause();
    }

    function unpause() public onlyWhiteListUser whenPaused {
        _unpause();
    }

    // function prefixed(bytes32 hash) internal pure returns (bytes32) {
    //     return
    //     keccak256(
    //         abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
    //     );
    // }

    // function recoverSigner(bytes32 message, bytes memory sig)
    // internal
    // pure
    // returns (address)
    // {
    //     uint8 v;
    //     bytes32 r;
    //     bytes32 s;

    //     (v, r, s) = splitSignature(sig);

    //     return ecrecover(message, v, r, s);
    // }

    // function splitSignature(bytes memory sig)
    // internal
    // pure
    // returns (
    //     uint8,
    //     bytes32,
    //     bytes32
    // )
    // {
    //     require(sig.length == 65);

    //     bytes32 r;
    //     bytes32 s;
    //     uint8 v;

    //     assembly {
    //     // first 32 bytes, after the length prefix
    //         r := mload(add(sig, 32))
    //     // second 32 bytes
    //         s := mload(add(sig, 64))
    //     // final byte (first byte of the next 32 bytes)
    //         v := byte(0, mload(add(sig, 96)))
    //     }

    //     return (v, r, s);
    // }

}


