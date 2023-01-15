require("@nomiclabs/hardhat-waffle");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
  },
  // defaultNetwork: "bsc-testnet",
  networks: {
    // localhost: {
    //   url: "http://127.0.0.1:8545",
    // },
    "bsc-testnet": {
      url: "https://data-seed-prebsc-2-s2.binance.org:8545",
      chainId: 97,
      gasPrice: 30000000000,
      accounts: [process.env.TESTNET_PRIVATE_KEY]
    },
    // bscmainnet: {
    //   url: "https://bsc-dataseed.binance.org/",
    //   chainId: 56,
    //   gasPrice: 20000000000,
    //   accounts: [PRI_KEY]
    // },
    // polygon: {
    //   url: "https://polygon-rpc.com/",
    //   chainId: 137,
    //   gasPrice: 35000000000,
    //   accounts: [PRI_KEY]
    // },
    // avax: {
    //   url: "https://api.avax.network/ext/bc/C/rpc",
    //   chainId: 43114,
    //   gasPrice: 35000000000,
    //   accounts: [PRI_KEY]
    // },
    // avaxtestnet: {
    //   url: "https://rpc.ankr.com/avalanche_fuji",
    //   chainId: 43113,
    //   gasPrice: 35000000000,
    //   accounts: [PRI_KEY]
    // },
    // op: {
    //   url: "https://mainnet.optimism.io/",
    //   chainId: 10,
    //   gasPrice: 35000000000,
    //   accounts: [PRI_KEY]
    // },
    // okc: {
    //   url: "https://exchainrpc.okex.org",
    //   chainId: 66,
    //   gasPrice: 20000000000,
    //   accounts: [PRI_KEY]
    // },
    // ethtestnet: {
    //   url: "https://goerli.infura.io/v3/2b39db58fa29458284b7b477dc8ed6b4",
    //   chainId: 5,
    //   gasPrice: 20000000000,
    //   accounts: [PRI_KEY]
    // },
    // eth: {
    //   url: "https://mainnet.infura.io/v3/f64eb559445047179a4ca592c3ddec64",
    //   chainId: 1,
    //   gasPrice: 10900000000,
    //   accounts: [PRI_KEY]
    // },
    // rinkeby: {
    //   url: 'https://rinkeby.infura.io/v3/2b39db58fa29458284b7b477dc8ed6b4',
    //   accounts: [PRI_KEY],      
    // }
  },
  // mocha: {
  //   timeout: 100000
  // },
  // etherscan: {
  //   apiKey: ETHERSCAN_API_KEY
  // }
}