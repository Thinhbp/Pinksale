const hre = require("hardhat");
const Web3 = require("web3");


async function main() {

    const GSAntiBot = await hre.ethers.getContractFactory("GSAntiBot");

    const gsAntiBot = await GSAntiBot.attach("0x1a8790c445cfAF93CC5425dAd83b0d67D2C8b381");// Test

    var token = "0xCEcA219409493F64AF1Deb0829035df1621044bE";
    var pairtoken = "0x0000000000000000000000000000000000000000";
    var rounterExchage = ""


   
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
//npx hardhat run scripts/ReferralBonus/init_data.js --network bsc-mainnet