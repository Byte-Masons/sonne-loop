const {ethers, upgrades} = require('hardhat');

async function main() {
  const strategyAddress = '0xcF14ef7C69166847c71913dc449c3958F55998d7';
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
