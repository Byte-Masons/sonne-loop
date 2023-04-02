async function main() {
  const vaultAddress = '0x73e51b0368Ef8bD0070b12DD992C54aA53BCB5F4';
  const strategyAddress = '0xfB0F98739C8437d38f7c1926787707766257E390';

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
