/*
npx hardhat run scripts/deploy.js --network <network-name>
npx hardhat run scripts/deploy_mytoken.js --network rinkeby 

*/
const hre = require('hardhat');
// const ethers = require('ethers');

async function main() {
    const [deployer] = await ethers.getSigners();

    // constructor(address _signer, address _superAccount, address _gsLock, address payable _fundAddress){

    const _signer = "0xc26b6c35e033AD5F174439271CFF659d6ee44EeD";
    const _superAccount = "0xc26b6c35e033AD5F174439271CFF659d6ee44EeD";
    const _gsLock = "0xa09ea19b47Cc9B3E275EfBeb53D1c8B1C57cb50f";
    const _fundAddress = "0xc26b6c35e033AD5F174439271CFF659d6ee44EeD";
    

    // console.log("Deploying contracts with the account:", deployer.address);
  
    // console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const contract = await hre.ethers.getContractFactory("DeployLaunchpad");
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