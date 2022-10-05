async function main() {
  const vaultAddress = '0x9Fb1db0252D9153F426FC585135B7696F8a37d96';
  const strategyAddress = '0x7F905c459772a805116FEc52530ccF1665Cddc36';

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
