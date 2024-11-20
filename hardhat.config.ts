import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'hardhat-deploy';
import 'hardhat-contract-sizer';
import 'hardhat-dependency-compiler';
import '@openzeppelin/hardhat-upgrades';
import "@typechain/hardhat";

import dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  defaultNetwork: "linea",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic:
            "blind blood loud next chicken diamond inquiry dove throw pig shuffle organ",
         // "burger broccoli appear involve admit own next member begin direct flee host seven game hat",
      },
      forking: {
        url: "https://sepolia.blast.io"
      }
    },
    blastSepolia: {
      url: "https://sepolia.blast.io",
      accounts: [process.env.WALLET_PRIVATE_KEY || ""],
      chainId: 168587773,
      gasPrice: 1000000000,
    },
    linea: {
      url: "https://rpc.linea.build",
      accounts: [process.env.WALLET_PRIVATE_KEY || ""],
    },
  },
  gasReporter: {
    enabled: true,
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
      },
      {
        version: "0.8.20",
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
  mocha: {
    timeout: 0,
    bail: true,
  },
};

export default config;
