const Hamster = artifacts.require('Hamster');
const HShare = artifacts.require('HShare');
const HamsterGenesisRewardPool = artifacts.require('HamsterGenesisRewardPool');
const HamsterRewardPool = artifacts.require('HamsterRewardPool');
const HShareRewardPool = artifacts.require('HShareRewardPool');

module.exports = async (_, __, [account]) => {
  const HAMSTER = '';
  const HSHARE = '';
  const AIRDROP_RECEIVER = '' || account;
  const AIRDROP_AMOUNT = '9000000000000000000000'; // 9000

  const hamster = await Hamster.at(HAMSTER);
  const hshare = await HShare.at(HSHARE);
  const genesisPool = await HamsterGenesisRewardPool.deployed();
  const hamsterPool = await HamsterRewardPool.deployed();
  const hsharePool = await HShareRewardPool.deployed();

  const GENESIS_POOL_AMOUNT = await genesisPool.totalRewards();
  let HAMSTER_POOL_AMOUNT = await hamsterPool.epochTotalRewards(0);
  await hamsterPool.epochTotalRewards(1)
    .then(res => HAMSTER_POOL_AMOUNT = (BigInt(HAMSTER_POOL_AMOUNT) + BigInt(res)).toString());
  const HSHARE_POOL_AMOUNT = await hsharePool.totalRewards();

  await hamster.distributeReward(
    genesisPool.address,
    GENESIS_POOL_AMOUNT,
    hamsterPool.address,
    HAMSTER_POOL_AMOUNT,
    AIRDROP_RECEIVER,
    AIRDROP_AMOUNT
  );
  await hshare.distributeReward(hsharePool.address, HSHARE_POOL_AMOUNT);
}
