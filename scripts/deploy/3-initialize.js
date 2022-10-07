async function main() {
  const vaultAddress = '0x42Cbc398f63855f89aFE225f5F90151B00D6C73C';
  const strategyAddress = '0x906ee3Cc53f2a59C0E338e8357c4490b1534896d';

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
