const Hamster = artifacts.require('Hamster');
const HShare = artifacts.require('HShare');
const HBond = artifacts.require('HBond');
const TaxOracle = artifacts.require('TaxOracle');
const Oracle = artifacts.require('Oracle');
const TaxOfficeV2 = artifacts.require('TaxOfficeV2');
const HamsterWheel = artifacts.require('HamsterWheel');
const Treasury = artifacts.require('Treasury');

module.exports = async (_, __, [account]) => {
  const COMMUNITY_FUND = '' || account;
  const DEV_FUND = '' || account;
  const HAMSTER = '';
  const HSHARE = '';
  const HBOND = '';
  const TREASURY_START_TIME = '0';
  const EXCLUDED_FROM_TOTAL_SUPPLY = [
    "", // HamsterGenesisPool
    ""  // HamsterRewardPool
  ];
  const COMMUNITY_FUND_SHARED_PERCENT = 1500;
  const DEV_FUND_SHARED_PERCENT = 500;

  const hamster = await Hamster.at(HAMSTER);
  const hshare = await HShare.at(HSHARE);
  const hbond = await HBond.at(HBOND);
  const taxOracle = await TaxOracle.deployed();
  const oracle = await Oracle.deployed();
  const treasury = await Treasury.deployed();
  const hamsterWheel = await HamsterWheel.deployed();
  const taxOfficeV2 = await TaxOfficeV2.deployed();

  // Treasury initialize
  await treasury.initialize(
    HAMSTER,
    HBOND,
    HSHARE,
    oracle.address,
    hamsterWheel.address,
    TREASURY_START_TIME,
    EXCLUDED_FROM_TOTAL_SUPPLY
  );

  // HamsterWheel initialize
  await hamsterWheel.initialize(HAMSTER, HSHARE, treasury.address);
  
  // Oracle update
  await oracle.update();

  // Treasury setExtraFunds
  await treasury.setExtraFunds(COMMUNITY_FUND, COMMUNITY_FUND_SHARED_PERCENT, DEV_FUND, DEV_FUND_SHARED_PERCENT);

  // Hamster setHamsterOracle
  await hamster.setHamsterOracle(taxOracle.address);

  // Hamster setTaxOffice
  await hamster.setTaxOffice(taxOfficeV2.address);

  // [Hamster, HShare, HBond, Oracle] transfer operator
  for (let contract of [hamster, hshare, hbond, oracle]) {
    await contract.transferOperator(treasury.address);
  }

  // HamsterWheel setOperator
  await hamsterWheel.setOperator(treasury.address);
}
 