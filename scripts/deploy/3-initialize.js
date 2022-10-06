async function main() {
  const vaultAddress = '0xC66b447BE01Ae5FEadBd6DC76D228c5143af9A3C';
  const strategyAddress = '0x071A922d81d604617AD5276479146bF9d7105EFC';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);

  //const options = { gasPrice: 2000000000000, gasLimit: 9000000 };
  await vault.initialize(strategyAddress);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
