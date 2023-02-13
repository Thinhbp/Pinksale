/*
npx hardhat run scripts/deploy.js --network <network-name>
npx hardhat run scripts/deploy_mytoken.js --network rinkeby 

*/
const hre = require('hardhat');
// const ethers = require('ethers');

async function main() {
    const [deployer] = await ethers.getSigners();

    const supply = 100_000_000;
    const antiBot = "0x1a8790c445cfAF93CC5425dAd83b0d67D2C8b381";
    const serviceFeeReceiver = "0xf0f221aCD03B84Df75b5ddbE39DF6f79fBb3EeD1";
    const serviceFee = 50000000000000000;


    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const Token = await hre.ethers.getContractFactory("AntiBotStandardToken");
    const token = await Token.deploy('Token1','TK1', 18, supply, antiBot, serviceFeeReceiver, serviceFee.toString(),{gasPrice: serviceFee.toString()});
  
    console.log("Token address:", token.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });