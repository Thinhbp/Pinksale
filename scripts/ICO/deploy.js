const hre = require("hardhat");
// const { getImplementationAddress } = require("@openzeppelin/upgrades-core");

async function main() {
    //npx hardhat run scripts/ICO/deploy.js --network bsc-mainnet
    //npx hardhat verify --network bsc-mainnet <sc address>

    const MstationPvE = await hre.ethers.getContractFactory("MstationPvE");
    const mstationSchool = await upgrades.deployProxy(MstationPvE);
    await mstationSchool.deployed();

    console.log("MstationPvE deployed to:", mstationSchool.address);

    // try {
    //     const nftImplAddress = await getImplementationAddress(
    //         mstation721.provider,
    //         mstation721.address
    //     );
    //     await hre.run("verify:verify", { address: nftImplAddress });
    //     console.log("Stonemason verified to:", nftImplAddress);
    // } catch (e) {

    // }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
    //https://mstation.atlassian.net/wiki/spaces/MSTATION/pages/2949121/Mstation+Upgrade+Level+smart+contract
//npx hardhat run scripts/MstationPvE/deploy.js --network bsc-mainnet
// DEV: 0x65162FB227e3DE0928C12d23B620bB6f92280145
// dev 0x134507f1b274c899a4b54c5b017901360bd92914
// dev 3: 0x0c0304716407449BF1b552E408a38F6f6BB21AfE

// staging: 0xA79adBE3dbbA18e72CABb10F31978CeBb2b169bA
//prod: 0x4BFBE60Cd5B7D6A73f12dba42014CB744b0C5D4a
// prod for test:
