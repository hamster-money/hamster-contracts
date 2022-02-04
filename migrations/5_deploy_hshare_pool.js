const HShareRewardPool = artifacts.require('HShareRewardPool');

module.exports = async (deployer) => {
  const HSHARE = '';
  const HSHARE_POOL_START_TIME = '0';
  const TOTAL_REWARDS = '59500000000000000000000'; // 59500
  const DURATION = (370n * 24n * 60n * 60n).toString(); // 370 days

  await deployer.deploy(
    HShareRewardPool,
    HSHARE,
    HSHARE_POOL_START_TIME,
    TOTAL_REWARDS,
    DURATION
  );
}
