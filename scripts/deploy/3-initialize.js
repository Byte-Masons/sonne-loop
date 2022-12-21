async function main() {
  const vaultAddress = '0x1e1BF73Db9b278A95c9fe9205759956EdEA8b6ae';
  const strategyAddress = '0x5C8765F08AeC9f117B58B83834Ca45c948A59ab1';

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
