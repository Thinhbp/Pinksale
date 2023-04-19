// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

//import "@openzeppelin/contracts/access/Ownable.sol";
//import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
//import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../FairLaunch/FairLaunch.sol";
//import "../interfaces/IGSERC20.sol";

contract DeployFairLaunchpad is Ownable {
    //using SafeMath for uint256;
    //using SafeERC20 for IGSERC20;

    address public signer;
    address public superAccount;
    address public gsLock;
    address payable public fundAddress;
    uint256 public percertAffiliate;

    event NewLaunchpadV2(address indexed launchpad);

    uint256 public constant ZOOM = 10000;

    constructor(address _signer, address _superAccount, address _gsLock, address payable _fundAddress){
        require(_signer != address(0) && _signer != address(this), 'signer');
        require(_gsLock != address(0) && _gsLock != address(this), 'gsLock');
        require(_superAccount != address(0) && _superAccount != address(this), 'superAccount');
        require(_fundAddress != address(0) && _fundAddress != address(this), 'fundAddress');
        signer = _signer;
        superAccount = _superAccount;
        fundAddress = _fundAddress;
        gsLock = _gsLock;
    }

    function setSigner(address _signer) public onlyOwner {
        signer = _signer;
    }

    function setSuperAccount(address _superAccount) public onlyOwner {
        superAccount = _superAccount;
    }

    function setGSLock(address _gsLock) public onlyOwner {
        gsLock = _gsLock;
    }

    function setFundAddress(address payable _fundAddress) public onlyOwner {
        fundAddress = _fundAddress;
    }


    
    function deployLaunchpad(LaunchpadStructs.LaunchpadInfo memory info,  LaunchpadStructs.DexInfo memory dexInfo, LaunchpadStructs.FeeSystem memory feeInfo, uint256 _percertAffiliate) external payable {
        require(signer != address(0) && superAccount != address(0) && fundAddress != address(0), 'Can not create launchpad now!');
        require(msg.value >= feeInfo.initFee, 'Not enough fee!');
        if (!info.affiliate) {
            percertAffiliate = 0;
        } else {
            require(_percertAffiliate >=100 && _percertAffiliate <=1000, "invalid");
            percertAffiliate = _percertAffiliate;
        }


        LaunchpadStructs.SettingAccount memory settingAccount = LaunchpadStructs.SettingAccount(
            _msgSender(),
            signer,
            superAccount,
            payable(fundAddress),
            gsLock
        );


        IGSERC20 icoToken = IGSERC20(info.icoToken);
  
        uint256 totalListing = info.totalIcoToken * (ZOOM - feeInfo.raisedFeePercent)*dexInfo.listingPercent / (ZOOM **2) + info.totalIcoToken * feeInfo.raisedTokenFeePercent/ (ZOOM);//0 if manual listing

        uint256 totalTokenNeeded = info.totalIcoToken + totalListing;



        FairLaunch fairLaunch = new FairLaunch(info,  dexInfo, feeInfo, settingAccount, percertAffiliate);

        if (msg.value > 0) {
            payable(fundAddress).transfer(msg.value);
        }

        if (totalTokenNeeded > 0) {
            IGSERC20 icoTokenErc20 = IGSERC20(info.icoToken);

            require(icoTokenErc20.balanceOf(_msgSender()) >= totalTokenNeeded, 'Insufficient Balance');
            require(icoTokenErc20.allowance(_msgSender(), address(this)) >= totalTokenNeeded, 'Insufficient Allowance');

            require(icoToken.transferFrom(_msgSender(), address(fairLaunch), totalTokenNeeded),"transfer failed");
        }
        emit NewLaunchpadV2(address(fairLaunch));
    }

}


