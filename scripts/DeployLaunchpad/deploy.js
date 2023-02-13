/*
npx hardhat run scripts/deploy.js --network <network-name>
npx hardhat run scripts/deploy_mytoken.js --network rinkeby 

*/
const hre = require('hardhat');
// const ethers = require('ethers');

async function main() {
    const [deployer] = await ethers.getSigners();

    // constructor(address _signer, address _superAccount, address _gsLock, address payable _fundAddress){

    const _signer = "0xf8D6cBd7c3bee733C0AF70171DBFf21d932c99c2";
    const _superAccount = "0xf8D6cBd7c3bee733C0AF70171DBFf21d932c99c2";
    // const _gsLock = "0x8a1b061E768324De2b5CCCFD263EfCfe3c35070d"; //testnet
    const _gsLock = "0x61A801d4A8969f9aC74afAC65A769EB0478EdcBC";
    const _fundAddress = "0xf8D6cBd7c3bee733C0AF70171DBFf21d932c99c2";
    

    // console.log("Deploying contracts with the account:", deployer.address);
  
    // console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const contract = await hre.ethers.getContractFactory("DeployLaunchpadV2");
    const contractD = await contract.deploy(_signer,_superAccount, _gsLock, _fundAddress);
  
    console.log("Contract address:", contractD.address);

    ////// INTERACTION /////////////
    // const sc = await contract.attach('0xf9971Dc735367c1BE99dd114943d1E6530ad5a0C');

    //lock address
    // console.log('gsLock', await sc.gsLock());

    // deploy launchpad
    // const launchpadInfo = [icoToken, feeToken, softCap, hardCap, presaleRate, minInvest, maxInvest, startTime, endTime, whitelistPool, poolType];
    // const claimInfo = [cliffVesting, lockAfterCliffVesting, firstReleasePercent, vestingPeriodEachCycle, tokenReleaseEachCycle];
    // const teamVestingInfo = [teamTotalVestingTokens, teamCliffVesting, teamFirstReleasePercent, teamVestingPeriodEachCycle, teamTokenReleaseEachCycle];
    // const dexInfo = [routerAddress, factoryAddress, listingPrice, listingPercent, lpLockTime];
    // const feeInfo = [ethers.utils.parseUnits(`${initLaunchpadFee}`, feeDec), raisedFeePercent, raisedTokenFeePercent, penaltyFee];
    // const deployFee = 0.5;
    // const transaction = await deployLaunchpadContract.deployLaunchpad(launchpadInfo, claimInfo, teamVestingInfo, dexInfo, feeInfo, { value: ethers.utils.parseUnits(`${deployFee}`, 18) });
    // console.log('transaction', transaction);


    // await sc.pause();
    // await sc.unpause();

    // let amt = 40000;
    // amt = await web3.utils.toWei(amt.toString(), "ether");
    // await sc.configAutoWithdraw(amt);
    // let storeAmt = await sc.maxStoreAmount();
    // console.log('storeAmt', web3.utils.fromWei(storeAmt.toString(), "ether"));


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });