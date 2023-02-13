const hre = require("hardhat");
const Web3 = require("web3");


async function main() {

    const LP = await hre.ethers.getContractFactory("DeployLaunchpadV2");

    // const lp = await LP.attach("0xc53868B5aeFd750f06f9e7e475FC6007d25D48B1");// Mainnet
    const lp = await LP.attach("0xF94dB6657F19d4aE5019ECc0C51D0581E2acB2B6");// Testnet
    const fundAddress = "0xbc7b4526D9342f9bF02a23ABcf9821370f5b8ce2";
    const gslock  = "0x70F628254C6b49a9406bcdeB37CfAC025129caA3"
    // await lp.setGSLock(gslock)
    const accLock = await lp.gsLock();
    console.log(accLock)




   
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
//npx hardhat run scripts/ReferralBonus/init_data.js --network bsc-mainnet