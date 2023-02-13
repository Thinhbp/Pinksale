/*
npx hardhat run scripts/deploy.js --network <network-name>
npx hardhat run scripts/deploy_mytoken.js --network rinkeby 

verify implementation contract in etherscan
*/
const hre = require('hardhat');
// const ethers = require('ethers');

async function main() {
  const [owner] = await ethers.getSigners();

  let _feeAmount = 10000000000000000;
  let _feeAddr = '0xbc7b4526D9342f9bF02a23ABcf9821370f5b8ce2';

  console.log("Deployer:", owner.address);

  const A = await hre.ethers.getContractFactory('GSAntiBot');
  const contract = await hre.upgrades.deployProxy(A,[_feeAddr, _feeAmount.toString()], {kind:'uups'});

  console.log("Contract deployed to:", contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });