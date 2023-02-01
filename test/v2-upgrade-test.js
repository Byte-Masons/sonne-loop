// REPLACE CONTENTS OF unknown-31337.json WITH CONTENTS OF unknown-10.json TO RUN THIS
const {ethers, network, upgrades} = require('hardhat');
const {expect} = require('chai');

describe.only('V2 Upgrade', function () {
  it('executes V2 upgrade successfully', async function () {
    await network.provider.request({
      method: 'hardhat_reset',
      params: [
        {
          forking: {
            jsonRpcUrl: 'https://late-fragrant-rain.optimism.quiknode.pro/70171d2e7790f3af6a833f808abe5e85ed6bd881/',
          },
        },
      ],
    });

    const strategyAddress = '0xcF14ef7C69166847c71913dc449c3958F55998d7';
    const StrategyV2 = await ethers.getContractFactory('ReaperStrategySonne');
    const strategyProxy = StrategyV2.attach(strategyAddress);
    const newImplAddress = await upgrades.prepareUpgrade(strategyAddress, StrategyV2);

    const superAdminAddress = '0x9BC776dBb134Ef9D7014dB1823Cd755Ac5015203';
    await network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [superAdminAddress],
    });
    const superAdmin = ethers.provider.getSigner(superAdminAddress);

    const [signer] = await ethers.getSigners();
    let tx = await signer.sendTransaction({
      to: superAdminAddress,
      value: ethers.utils.parseEther('5'),
    });
    await tx.wait();

    await strategyProxy
      .connect(superAdmin)
      .upgradeToAndCall(
        newImplAddress,
        StrategyV2.interface.encodeFunctionData('completeV2Upgrade'),
      );

    // verify upgrade flag
    expect(await strategyProxy.v2UpgradeCompleted()).to.be.true;

    // verify keepers
    const KEEPER = '0x71a9859d7dd21b24504a6f306077ffc2d510b4d4b61128e931fe937441ad1836';
    expect(await strategyProxy.hasRole(KEEPER, '0x33D6cB7E91C62Dd6980F16D61e0cfae082CaBFCA')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x34Df14D42988e4Dc622e37dc318e70429336B6c5')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x36a63324edFc157bE22CF63A6Bf1C3B49a0E72C0')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x51263D56ec81B5e823e34d7665A1F505C327b014')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x5241F63D0C1f2970c45234a0F5b345036117E3C2')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x5318250BD0b44D1740f47a5b6BE4F7fD5042682D')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x55a078AFC2e20C8c20d1aa4420710d827Ee494d4')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x73C882796Ea481fe0A2B8DE499d95e60ff971663')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x7B540a4D24C906E5fB3d3EcD0Bb7B1aEd3823897')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x8456a746e09A18F9187E5babEe6C60211CA728D1')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x87A5AfC8cdDa71B5054C698366E97DB2F3C2BC2f')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0x9a2AdcbFb972e0EC2946A342f46895702930064F')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0xd21E0fE4ba0379Ec8DF6263795c8120414Acd0A3')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0xe0268Aa6d55FfE1AA7A77587e56784e5b29004A2')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0xf58d534290Ce9fc4Ea639B8b9eE238Fe83d2efA6')).to.be.true;
    expect(await strategyProxy.hasRole(KEEPER, '0xCcb4f4B05739b6C62D9663a5fA7f1E2693048019')).to.be.true;
    
    // verify security fee + call fee + treasury fee
    expect(await strategyProxy.securityFee()).to.equal(ethers.constants.Zero);
    expect(await strategyProxy.callFee()).to.equal(ethers.constants.Zero);
    expect(await strategyProxy.treasuryFee()).to.equal(ethers.BigNumber.from(10_000));

    // try harvesting from random account, should fail
    await expect(strategyProxy.connect(signer).harvest()).to.be.reverted;
    
    // try harvesting with keeper, should pass
    const keeperAddress = '0xCcb4f4B05739b6C62D9663a5fA7f1E2693048019';
    await network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [keeperAddress],
    });
    const keeper = ethers.provider.getSigner(keeperAddress);

    tx = await signer.sendTransaction({
      to: keeperAddress,
      value: ethers.utils.parseEther('3'),
    });
    await tx.wait();
    tx = await strategyProxy.connect(keeper).harvest();
    await tx.wait();
  });
});