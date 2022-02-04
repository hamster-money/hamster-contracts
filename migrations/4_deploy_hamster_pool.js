const HamsterRewardPool = artifacts.require('HamsterRewardPool');

module.exports = async (deployer) => {
  const HAMSTER = '';
  const HAMSTER_POOL_START_TIME = '0';
  const FIRST_EPOCH_AMOUNT = '80000000000000000000000'; // 80000
  const FIRST_EPOCH_DURATION = (4n * 24n * 60n * 60n).toString(); // 4 days
  const SECOND_EPOCH_AMOUNT = '60000000000000000000000'; // 60000
  const SECOND_EPOCH_DURATION = (5n * 24n * 60n * 60n).toString(); // 5 days

  await deployer.deploy(
    HamsterRewardPool,
    HAMSTER,
    HAMSTER_POOL_START_TIME,
    FIRST_EPOCH_AMOUNT,
    FIRST_EPOCH_DURATION,
    SECOND_EPOCH_AMOUNT,
    SECOND_EPOCH_DURATION
  );
}
