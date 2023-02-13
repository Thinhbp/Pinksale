const hre = require("hardhat");
const Web3 = require("web3");


async function main() {

    const GSLock = await hre.ethers.getContractFactory("GSLock");


    const gslock = await GSLock.attach("0x70F628254C6b49a9406bcdeB37CfAC025129caA3");//Test

    // var token = "0xCEcA219409493F64AF1Deb0829035df1621044bE";
    // var pairtoken = "0x0000000000000000000000000000000000000000";
    // var rounterExchage = ""
    // var fundAmount =  await gsAntiBot.fundAmount();
    // console.log(fundAmount);

    const fee  = Web3.utils.toWei('.0001', 'ether');
    const feeWallet = "0x197eE7A0515158225B3A19d9552b894Ff6a55E9b";

    const token  = "0x9b219ec76A740F84f6e4ff976f88F6019d32C81e";

    const owner = "0xf8D6cBd7c3bee733C0AF70171DBFf21d932c99c2"
    const isLpToken = false
    const amount = Web3.utils.toWei('100', 'ether');
    const unlockDate = 16762880001
    const tgeDate = 16762890001;
    const tgeBps = 50
    const cycle = 2
    const cycleBps = 10
    // const id  = await gslock.lock(owner, token, isLpToken, amount,unlockDate,"aaaa",{value : fee})

    const id = await gslock.vestingLock(owner, token, isLpToken, amount, tgeDate, tgeBps,cycle, cycleBps, "aaaa", {value : fee})

    // await gslock.setFee(fee)
    // await gslock.setFeeWallet(feeWallet)


   
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
//npx hardhat run scripts/ReferralBonus/init_data.js --network bsc-mainnet