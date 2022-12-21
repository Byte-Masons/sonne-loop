async function main() {
  const vaultAddress = '0x875456B73cBC58aA1bE98DfE3B0459e0C0Bf7b0e';
  const strategyAddress = '0xe726586f11bfB7856d4C52c77CdC5ff333953E15';

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
