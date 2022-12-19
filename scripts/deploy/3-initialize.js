async function main() {
  const vaultAddress = '0x42ab3Ef2E6F8D625F4bAF7724F35946C49a06b4F';
  const strategyAddress = '0x1F45AFDDb111e8B118464051ac555CD108353c87';

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
