async function main() {
  const vaultAddress = '0x79dee4f059e9e1c3fE2b7d26ab0b9454871B64C5';
  const strategyAddress = '0xDfAd8B746671480f72bB47e2A724a113Fe01F096';

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
