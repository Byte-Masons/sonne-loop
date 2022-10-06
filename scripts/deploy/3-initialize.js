async function main() {
  const vaultAddress = '0xD84D315f22565399ABFCb2b9C836955401C01A47';
  const strategyAddress = '0xcF14ef7C69166847c71913dc449c3958F55998d7';

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
