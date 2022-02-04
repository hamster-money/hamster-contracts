const TaxOracle = artifacts.require('TaxOracle');
const Oracle = artifacts.require('Oracle');
const TaxOfficeV2 = artifacts.require('TaxOfficeV2');
const HamsterWheel = artifacts.require('HamsterWheel');
const Treasury = artifacts.require('Treasury');
const HamsterZapper = artifacts.require('HamsterZapper');

module.exports = async (deployer) => {
  const HAMSTER = '';
  const HSHARE = '';
  const HAMSTER_PAIR = '';
  const WFTM = '';
  const ROUTER = '0xcCAFCf876caB8f9542d6972f87B5D62e1182767d';
  const ORACLE_START_TIME = '0';

  // TaxOracle
  await deployer.deploy(TaxOracle, HAMSTER, WFTM, HAMSTER_PAIR);

  // Treasury
  await deployer.deploy(Treasury);
  const treasury = await Treasury.deployed();
  const PERIOD = await treasury.PERIOD();

  // Oracle
  await deployer.deploy(Oracle, HAMSTER_PAIR, PERIOD, ORACLE_START_TIME);

  // HamsterWheel
  await deployer.deploy(HamsterWheel);

  // TaxOfficeV2
  await deployer.deploy(TaxOfficeV2, HAMSTER, ROUTER);

  // HamsterZapper
  await deployer.deploy(HamsterZapper, HAMSTER, HSHARE, ROUTER, WFTM);
}
 