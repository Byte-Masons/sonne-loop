async function main() {
  const vaultAddress = '0x88DbE71408DC20C82Ce44d919D7f521717352636';
  const strategyAddress = '0xdE261a231Af98b9A9fd01462Fe84eB53c11AEBbd';

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
