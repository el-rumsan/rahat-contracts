/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('solidity-coverage');
require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-waffle');

module.exports = {
  solidity: {
    version: '0.8.23',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: './src/rahat-app',
    tests: './tests',
    cache: './hardhat_build/cache',
    artifacts: './hardhat_build/artifacts',
  },
};
