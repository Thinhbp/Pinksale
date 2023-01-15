// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./GSAirDrop.sol";
import "./structs/AirDropStructs.sol";

contract DeployAirDrop is Ownable {
    using SafeMath for uint256;

    address public superAccount;
    address payable public fundAddress;

    event NewAirDrop(address indexed airDrop);


    constructor(address _superAccount, address payable _fundAddress){
        require(_superAccount != address(0) && _superAccount != address(this), 'invalid superAccount');
        require(_fundAddress != address(0) && _fundAddress != address(this), 'invalid superAccount');
        superAccount = _superAccount;
        fundAddress = _fundAddress;
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


    function deployAirDrop(IERC20 _airDropToken,
        uint256 _fundPercent,
        uint256 _amount) external payable {

        require(superAccount != address(0), 'Can not create launchpad now!');
        require(fundAddress != address(0), 'Invalid Fund Address');
        require(msg.value >= _amount, 'Invalid amount');

        GSAirDrop airDrop = new GSAirDrop(_airDropToken, fundAddress, _fundPercent, superAccount, _msgSender());

        if (msg.value > 0) {
            payable(fundAddress).transfer(msg.value);
        }
        emit NewAirDrop(address(airDrop));
    }

    function getAirDrops(address[] memory gsAirDrops) external view returns (AirDropStructs.AirDropFlashInfo[] memory) {

        AirDropStructs.AirDropFlashInfo[] memory result = new AirDropStructs.AirDropFlashInfo[](gsAirDrops.length);
        for (uint256 i = 0; i < gsAirDrops.length; i++) {
            AirDropStructs.AirDropFlashInfo memory info;
            GSAirDrop gsAirDrop = GSAirDrop(gsAirDrops[i]);

            try gsAirDrop.allAllocationCount() returns (uint256  v) {
                info.tokenAddress = address(gsAirDrop.airDropToken());
                info.totalAllocations = v;
                info.totalClaimedAllocations = gsAirDrop.userClaimedTokens();
                info.totalTokens = gsAirDrop.totalAllocationTokens();
                info.tgeDate = gsAirDrop.tgeDate();
                info.state = gsAirDrop.airDropState();

                result[i] = info;

            } catch Error(string memory /*reason*/) {
                continue;
            } catch (bytes memory /*lowLevelData*/) {
                continue;
            }
        }
        return result;


    }


}


