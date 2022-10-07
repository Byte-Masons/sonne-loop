async function main() {
  const vaultAddress = '0x932b30B2bC3f00B77AFFce8D0FF70B536F658462';
  const strategyAddress = '0x711C071F1a0C0cC85cAFD4120daa7B252533B57E';

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
