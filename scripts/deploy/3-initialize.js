async function main() {
  const vaultAddress = '0x94204607208f763b8DcC22232f9Fd2a51F8FC14b';
  const strategyAddress = '0x23394cc9847E0Ee02f23d9802524b793c48D4667';

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
