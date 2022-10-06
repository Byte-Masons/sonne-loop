async function main() {
  const vaultAddress = '0x89AC9ceFC4E69B484fb46602964B38380FD19fb5';
  const strategyAddress = '0x5ef8c33953DE22871f413FE470650Fcd17D79362';

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
