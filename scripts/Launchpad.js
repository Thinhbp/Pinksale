const hre = require("hardhat");
const Web3 = require("web3")


async function main() {
    //npx hardhat run scripts/MstationNFT/init_data.js --network bsc-testnet
    const Launchpad = await hre.ethers.getContractFactory("LaunchpadV2");

    const launchpad = await Launchpad.attach("0x087fd0c6acb150f05019c1374cd7ff207f9678d8");// Test
    // var info = await launchpad.getLaunchpadInfo() ;
    // console.log(info)
    //var amount = Web3.utils.toWei('0.005', 'ether');

    // var info = await launchpad.getAllocations(0,1) ;
    // console.log(info)

    // var info  = await launchpad.whitelistPool();
    // // // console.log(info)
    var user = "0x197eE7A0515158225B3A19d9552b894Ff6a55E9b";
    // var info = await launchpad.joinInfos(user);
    // console.log(info)

    //  var time = await launchpad.listingTime();
    // console.log(time)
    // // var firstReleasePercent= await launchpad.firstReleasePercent();
    // // console.log(firstReleasePercent);

    // var amount= await launchpad.getUserClaimAble(user);
    // console.log(amount);
    await launchpad.claimTokens();

    // var cliffVesting = await launchpad.cliffVesting();
    // console.log(cliffVesting);

    // var lockAfterCliffVesting = await launchpad.lockAfterCliffVesting();
    // console.log(lockAfterCliffVesting);





 
    
    // // console.log(endtime);
    // user = "0xE55FA59CfAFF5584F2b36d75FffcB52b7aA3e033"

    // var info = await launchpad. whitelistPool();
    // console.log(info)
    // var maxInvest = await launchpad.maxInvest();
    // console.log(maxInvest)

    // var minInvest = await launchpad.minInvest();
    // console.log(minInvest)

    // await launchpad.contribute(amount, {value : amount});
    // await launchpad.finalizeLaunchpad()





//      listwhitelist = await launchpad.listOfWhiteListUsers();
//      console.log(listwhitelist);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
//npx hardhat run scripts/ReferralBonus/init_data.js --network bsc-mainnet