/*
npx hardhat run scripts/deploy.js --network <network-name>
npx hardhat run scripts/deploy_mytoken.js --network rinkeby 

*/
const hre = require('hardhat');
// const ethers = require('ethers');

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const gsLock = await hre.ethers.getContractFactory("GSLock");
    const GSLockSC = await gsLock.deploy();
  
    console.log("GSLock address:", GSLockSC.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });