const {ethers, upgrades} = require('hardhat');

async function main() {
  const strategyAddress = '0x071A922d81d604617AD5276479146bF9d7105EFC';
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
