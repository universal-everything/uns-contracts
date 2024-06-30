import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-foundry';

function getTestnetChainConfig() {
  const config = {
    live: true,
    url: 'https://rpc.testnet.lukso.network',
    chainId: 4201,
    accounts: [''],
  };

  return config;
}
//
const config = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        /**
         * Optimize for how many times you intend to run the code.
         * Lower values will optimize more for initial deployment cost, higher
         * values will optimize more for high-frequency usage.
         * @see https://docs.soliditylang.org/en/v0.8.6/internals/optimizer.html#opcode-based-optimizer-module
         */
        runs: 100000,
      },
    },
  },
  networks: {
    luksoTestnet: getTestnetChainConfig(),
  },
  namedAccounts: {
    deployer: 0,
  },
};

export default config;
