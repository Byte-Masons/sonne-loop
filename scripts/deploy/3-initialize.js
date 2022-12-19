async function main() {
  const vaultAddress = '0xb76086387B8d710Fb5a9179ec474b3c6e39aD7C6';
  const strategyAddress = '0x4D3356c65E20A2b9313D0B49BFFd2af5bBc96ec7';

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
