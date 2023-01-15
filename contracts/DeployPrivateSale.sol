// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./PrivateSale.sol";

contract DeployPrivateSale is Ownable {

    address public superAccount;
    address payable public fundAddress;
    address public signer;
    uint256 public penaltyFeePercent = 1000;


    event NewPrivateSale(address indexed pvSale);

    constructor(address _signer, address _superAccount, address payable _fundAddress){
        require(_superAccount != address(0) && _superAccount != address(this), 'invalid superAccount');
        require(_fundAddress != address(0) && _fundAddress != address(this), 'invalid fundAddress');
        require(_signer != address(0) && _signer != address(this), 'invalid signer');
        superAccount = _superAccount;
        fundAddress = _fundAddress;
        signer = _signer;
    }


    function setSigner(address _signer) public onlyOwner {
        require(_signer != address(0) && _signer != address(this), 'invalid signer');
        require(signer != _signer, 'No need to update!');
        signer = _signer;
    }


    function setSuperAccount(address _superAccount) public onlyOwner {
        require(_superAccount != address(0) && _superAccount != address(this), 'invalid superAccount');
        require(superAccount != _superAccount, 'No need to update!');
        superAccount = _superAccount;
    }


    function setFundAddress(address payable _fundAddress) public onlyOwner {
        require(_fundAddress != address(0) && _fundAddress != address(this), 'invalid fundAddress');
        require(fundAddress != _fundAddress, 'No need to update!');
        fundAddress = _fundAddress;
    }



    function setPenaltyFeePercent(uint256  _penaltyFeePercent) public onlyOwner {
        require(penaltyFeePercent != _penaltyFeePercent, 'No need to update!');
        penaltyFeePercent = _penaltyFeePercent;
    }


    function deployPrivateSale(PrivateSaleStructs.PrivateSaleInfo memory _privateSaleInfo, PrivateSaleStructs.VestingInfo memory _vestingInfo, uint256 _fee, uint256 _funPercent) external payable {
        require(signer != address(0) && superAccount != address(0), 'Can not create private sale now!');
        require(msg.value >= _fee, 'Not enough fee!');
        require(fundAddress != address(0), 'Invalid Fund Address');
        require(penaltyFeePercent <= 10_000, 'Invalid Penalty Percent');
        require(_funPercent <= 10_000, 'Invalid Fund Percent');


        PrivateSaleStructs.DeployInfo memory deployInfo = PrivateSaleStructs.DeployInfo(
            fundAddress,
            _funPercent,
            superAccount,
            _msgSender(),
            signer,
            penaltyFeePercent
        );

        PrivateSale privateSale = new PrivateSale(deployInfo, _privateSaleInfo, _vestingInfo);
        if (msg.value > 0) {
            payable(fundAddress).transfer(msg.value);
        }

        emit NewPrivateSale(address(privateSale));
    }

}


