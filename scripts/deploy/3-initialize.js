async function main() {
  const vaultAddress = '0xA75a9af9626Bb6eb2684Fc5b5a2348CeBb89a1dA';
  const strategyAddress = '0xE095a5B61B6Cc27eD755dAE84884914133c7cB8B';

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
