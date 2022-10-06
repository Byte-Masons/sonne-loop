async function main() {
  const vaultAddress = '0x1891A76d191d5A24bcd06DeA4ACadF4b8aE4b583';
  const strategyAddress = '0x566c68Cd2f1e8b6D780c342B207B60c9c4f32767';

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
