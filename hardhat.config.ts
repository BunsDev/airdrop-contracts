import fs from "fs";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-preprocessor";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-deploy";

import { config as dotenvConfig } from "dotenv";

dotenvConfig();


let accounts;
if (process.env.PRIVATE_KEY) {
  accounts = [process.env.PRIVATE_KEY];
} else {
  accounts = {
    mnemonic: process.env.MNEMONIC ||
      "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat"
  }
}

/**
 * Required for foundry compatability: 
 * https://book.getfoundry.sh/config/hardhat
 */
export function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

const config: HardhatUserConfig = {
  solidity: "0.8.19",
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  paths: {
    sources: "./src",
    cache: "./cache_hardhat",
  },
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: { default: 0 },
    alice: { default: 1 },
    bob: { default: 2 },
    rando: { default: 3 },
  },
  etherscan: {
    apiKey: {
      // testnets
      goerli: process.env.ETHERSCAN_API_KEY!,
      optimisticGoerli: process.env.OPTIMISM_ETHERSCAN_API_KEY!,
      arbitrumGoerli: process.env.ARBISCAN_API_KEY!,
      chiado: process.env.GNOSISSCAN_API_KEY!,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY!,
      // mainnets
      mainnet: process.env.ETHERSCAN_API_KEY!,
      polygon: process.env.POLYGONSCAN_API_KEY!,
      optimisticEthereum: process.env.OPTIMISM_ETHERSCAN_API_KEY!,
      bsc: process.env.BNBSCAN_API_KEY!,
      arbitrumOne: process.env.ARBISCAN_API_KEY!,
      gnosis: process.env.GNOSISSCAN_API_KEY!,
    },
    customChains: [
      {
        network: "gnosis",
        chainId: 100,
        urls: {
          apiURL: "https://api.gnosisscan.io/api",
          browserURL: "https://api.gnosisscan.io",
        },
      },
    ]
  },
  networks: {
    mainnet: {
      accounts,
      chainId: 1,
      url: process.env.MAINNET_RPC_URL || "https://cloudflare-eth.com",
    },
    optimism: {
      accounts,
      chainId: 10,
      url: process.env.OPTIMISM_RPC_URL || "https://mainnet.optimism.io",
    },
    bnb: {
      accounts,
      chainId: 56,
      url: process.env.BNB_RPC_URL || "https://bsc-dataseed.binance.org/",
    },
    gnosis: {
      accounts,
      chainId: 100,
      url: process.env.GNOSIS_RPC_URL || "https://rpc.ankr.com/gnosis",
    },
    polygon: {
      accounts,
      chainId: 137,
      url: process.env.POLYGON_RPC_URL || "https://rpc.ankr.com/polygon",
    },
    "arbitrum-one": {
      accounts,
      chainId: 42161,
      url: process.env.ARB1_RPC_URL || "https://arb1.arbitrum.io/rpc",
    },

    // TESTNETS
    goerli: {
      accounts,
      chainId: 5,
      url:
        process.env.GOERLI_RPC_URL ||
        "https://goerli.infura.io/v3/7672e2bf7cbe427e8cd25b0f1dde65cf",
    },
    "optimism-goerli": {
      accounts,
      chainId: 420,
      url: process.env.OPTIMISM_GOERLI_RPC_URL || "https://optimism-goerli.infura.io/v3/7672e2bf7cbe427e8cd25b0f1dde65cf",
    },
    mumbai: {
      accounts,
      chainId: 80001,
      url:
        process.env.MUMBAI_RPC_URL ||
        "https://polygon-mumbai.infura.io/v3/7672e2bf7cbe427e8cd25b0f1dde65cf",
    },
    "arbitrum-goerli": {
      accounts,
      chainId: 421613,
      url:
        process.env.ARBITRUM_GOERLI_RPC_URL ||
        "https://arbitrum-goerli.infura.io/v3/7672e2bf7cbe427e8cd25b0f1dde65cf",
    },
    "gnosis-testnet": {
      accounts,
      chainId: 10200,
      url: process.env.GNOSIS_TESTNET_RPC_URL || "https://rpc.chiadochain.net",
    }
  }
};

export default config;
