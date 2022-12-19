async function main() {
  const vaultAddress = '0x2c761Ed6886867Aa3C4E258253982987326Cb929';
  const strategyAddress = '0x049769cF5803c57AB1Da4D192DEe34bAaF4668C9';

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
