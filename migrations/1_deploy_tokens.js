const Hamster = artifacts.require('Hamster');
const HShare = artifacts.require('HShare');
const HBond = artifacts.require('HBond');
const MockedHamster = artifacts.require('MockedHamster');
const MockedHShare = artifacts.require('MockedHShare');

module.exports = async (deployer, network, [account]) => {
  const COMMUNITY_FUND = '' || account;
  const DEV_FUND = '' || account;

  const HAMSTER_TAX_RATE = 0;
  const HAMSTER_INITIAL_MINT = '1000000000000000000';

  const HSHARE_START_TIME = "0";
  const HSHARE_INITIAL_MINT = '1000000000000000000';
  const HSHARE_VESTING_DURATION = (365n * 24n * 60n * 60n).toString();
  const HSHARE_COMMUNITY_FUND_ALLOCATION = '5500000000000000000000';
  const HSHARE_DEV_FUND_ALLOCATION = '5000000000000000000000';

  const hamsterContract = network == 'mainnet' ? Hamster : MockedHamster;
  const hshareContract = network == 'mainnet' ? HShare : MockedHShare;

  // Hamster contract
  await deployer.deploy(hamsterContract, HAMSTER_TAX_RATE, COMMUNITY_FUND, HAMSTER_INITIAL_MINT);

  // HShare contract
  await deployer.deploy(
    hshareContract,
    HSHARE_START_TIME,
    HSHARE_INITIAL_MINT,
    HSHARE_VESTING_DURATION,
    COMMUNITY_FUND,
    HSHARE_COMMUNITY_FUND_ALLOCATION,
    DEV_FUND,
    HSHARE_DEV_FUND_ALLOCATION
  );

  // HBond contract
  await deployer.deploy(HBond);
}
