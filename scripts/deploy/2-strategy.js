const hre = require('hardhat');

async function main() {
  const vaultAddress = '';

  const Strategy = await ethers.getContractFactory('ReaperStrategySonne');

  const treasuryAddress = '0xeb9C9b785aA7818B2EBC8f9842926c4B9f707e4B';

  const strategist1 = '0x1E71AEE6081f62053123140aacC7a06021D77348';
  const strategist2 = '0x81876677843D00a7D792E1617459aC2E93202576';
  const strategist3 = '0x1A20D7A31e5B3Bc5f02c8A146EF6f394502a10c4';

  const superAdmin = '0x9BC776dBb134Ef9D7014dB1823Cd755Ac5015203';
  const admin = '0xeb9C9b785aA7818B2EBC8f9842926c4B9f707e4B';
  const guardian = '0xb0C9D5851deF8A2Aac4A23031CA2610f8C3483F9';
  const keepers = [
    '0x33D6cB7E91C62Dd6980F16D61e0cfae082CaBFCA',
    '0x34Df14D42988e4Dc622e37dc318e70429336B6c5',
    '0x36a63324edFc157bE22CF63A6Bf1C3B49a0E72C0',
    '0x51263D56ec81B5e823e34d7665A1F505C327b014',
    '0x5241F63D0C1f2970c45234a0F5b345036117E3C2',
    '0x5318250BD0b44D1740f47a5b6BE4F7fD5042682D',
    '0x55a078AFC2e20C8c20d1aa4420710d827Ee494d4',
    '0x73C882796Ea481fe0A2B8DE499d95e60ff971663',
    '0x7B540a4D24C906E5fB3d3EcD0Bb7B1aEd3823897',
    '0x8456a746e09A18F9187E5babEe6C60211CA728D1',
    '0x87A5AfC8cdDa71B5054C698366E97DB2F3C2BC2f',
    '0x9a2AdcbFb972e0EC2946A342f46895702930064F',
    '0xd21e0fe4ba0379ec8df6263795c8120414acd0a3',
    '0xe0268Aa6d55FfE1AA7A77587e56784e5b29004A2',
    '0xf58d534290Ce9fc4Ea639B8b9eE238Fe83d2efA6',
  ];

  const soWant = '0xEC8FEa79026FfEd168cCf5C627c7f486D77b765F';

  const targetLtv = ethers.utils.parseEther('0.78');

  // const options = { gasPrice: 2000000000000, gasLimit: 9000000 };

  const strategy = await hre.upgrades.deployProxy(
    Strategy,
    [
      vaultAddress,
      treasuryAddress,
      [strategist1, strategist2, strategist3],
      [superAdmin, admin, guardian],
      soWant,
      targetLtv,
    ],
    { kind: 'uups' },
  );
  await strategy.deployed();
  console.log('Strategy deployed to:', strategy.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
