const {ethers, upgrades} = require('hardhat');

async function main() {
  const strategyAddress = '0x566c68Cd2f1e8b6D780c342B207B60c9c4f32767';
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
