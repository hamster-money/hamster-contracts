const HamsterGenesisRewardPool = artifacts.require('HamsterGenesisRewardPool');
const MockedComissionToken = artifacts.require('MockedComissionToken');

module.exports = async (deployer, network) => {
  const HAMSTER = '';
  let comissionTokens = [];
  const COMISSION_PERCENT = '100'; // 1%
  const HAMSTER_GENESIS_POOL_START_TIME = '0';
  const TOTAL_REWARDS = '11000000000000000000000'; // 11000
  const DURATION = (24n * 60n * 60n).toString(); // 1 day

  if (network == 'testnet') {
    await deployer.deploy(MockedComissionToken);
    await MockedComissionToken.deployed().then(res => comissionTokens.push(res.address));
  }

  await deployer.deploy(
    HamsterGenesisRewardPool,
    HAMSTER,
    comissionTokens,
    COMISSION_PERCENT,
    HAMSTER_GENESIS_POOL_START_TIME,
    TOTAL_REWARDS,
    DURATION
  );
}
