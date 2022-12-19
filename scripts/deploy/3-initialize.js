async function main() {
  const vaultAddress = '0xAA27053c78ceFE2bB96e7aCa312062E67650fFe5';
  const strategyAddress = '0xFe0B8Ce2Fbe738756768E72CCB42A371c01593A9';

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
