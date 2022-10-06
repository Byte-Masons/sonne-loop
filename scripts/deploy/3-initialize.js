async function main() {
  const vaultAddress = '0xB62100d94436f53a87516f1aa3Cf42f8A96Ae049';
  const strategyAddress = '0xFa72b38F6C6e6661db9C7b3585B4C9B823Fb979C';

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
