const MockedHamster = artifacts.require('MockedHamster');
const MockedHShare = artifacts.require('MockedHShare');
const Hamster = artifacts.require('Hamster');
const HShare = artifacts.require('HShare');
const IWFTM = artifacts.require('IWFTM');
const Router = artifacts.require('IUniswapV2Router');
const Factory = artifacts.require('IUniswapV2Factory');
const MockedWFTM = artifacts.require('MockedWFTM');

async function addLiquidity(t0, t1, router, t1Multiplyer, to) {
  const AMOUNT = '100000000000000000000000000000';
  const T1AMOUNT = (BigInt(AMOUNT) * BigInt(t1Multiplyer)).toString();
  const TIMESTAMP = await web3.eth.getBlock('latest').then(
    (r) => (BigInt(r.timestamp) + 10000000n).toString());
  await t0.mint(AMOUNT);
  await t1.mint(T1AMOUNT);
  await t0.approve(router.address, AMOUNT);
  await t1.approve(router.address, T1AMOUNT);
  await router.addLiquidity(
    t0.address,
    t1.address,
    AMOUNT,
    T1AMOUNT,
    1,
    1,
    to,
    TIMESTAMP
  );
}

async function showPairs(factory, hamster, hshare, wftm) {
  await factory.getPair(hamster, wftm).then(res => console.log("HAMSTER PAIR: ", res));
  await factory.getPair(hshare, wftm).then(res => console.log("HSHARE PAIR: ", res));
}

module.exports = async (deployer, network, [account]) => {
  let factory;
  let hamster;
  let hshare;
  let wftm;
  if (network == 'testnet') {
    const ROUTER = '0xcCAFCf876caB8f9542d6972f87B5D62e1182767d';
    const HAMSTER_PRICE = 1;
    const HSHARE_PRICE = 3;
    await deployer.deploy(MockedWFTM);
    wftm = await MockedWFTM.deployed();
    hamster = await MockedHamster.deployed();
    hshare = await MockedHShare.deployed();
    const router = await Router.at(ROUTER);
    const FACTORY = await router.factory();
    factory = await Factory.at(FACTORY);
    await addLiquidity(hamster, wftm, router, HAMSTER_PRICE, account);
    await addLiquidity(hshare, wftm, router, HSHARE_PRICE, account);
  } else if (network == 'mainnet') {
    const HAMSTER = '';
    const HSHARE = '';
    const WFTM = '';
    const FACTORY = '';
    hamster = await Hamster.at(HAMSTER);
    hshare = await HShare.at(HSHARE);
    wftm = await IWFTM.at(WFTM); 
    factory = await Factory.at(FACTORY);
  }
  await showPairs(factory, hamster.address, hshare.address, wftm.address);
}
