async function main() {
  const vaultAddress = '0x19b9bf8f80267dFcbd16F404ecFEF659231dB140';
  const strategyAddress = '0xed1Dee9e641B5b3cd6691ab337ac1AAa5515a07f';

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
