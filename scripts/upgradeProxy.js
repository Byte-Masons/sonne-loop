const {ethers, upgrades} = require('hardhat');

async function main() {
  const strategyAddress = '0x711C071F1a0C0cC85cAFD4120daa7B252533B57E';
  const StrategyV2 = await ethers.getContractFactory('ReaperStrategySonne');
  const newImplAddress = await upgrades.prepareUpgrade(strategyAddress, StrategyV2, {
    timeout: 0,
    kind: 'uups',
  });
  console.log(newImplAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
