const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('RahatClaim', function () {
  let deployer;
  let claimer;
  let claimee;
  let otpServer;
  let token;
  let rahatClaimContract;

  before(async function () {
    [deployer, claimer, claimee, otpServer, token] = await ethers.getSigners();
  });

  beforeEach(async function () {
    rahatClaimContract = await ethers.deployContract('RahatClaim')
  });

  it('Should create claim', async function () {
    await expect(
      rahatClaimContract.createClaim(
        claimer.address,
        claimee.address,
        otpServer.address,
        token.address
      )
    )
    .to.emit(rahatClaimContract, 'ClaimCreated')
    .withArgs(1, claimer.address, claimee.address, token.address, otpServer.address);

    const claim = await rahatClaimContract.claims(1);
    expect(claim.claimerAddress).to.equal(claimer.address);
    expect(claim.claimeeAddress).to.equal(claimee.address);
    expect(claim.otpServerAddress).to.equal(otpServer.address);
    expect(claim.tokenAddress).to.equal(token.address);
    expect(claim.isProcessed).to.be.false;
  });

  it('Should add OTP to claim', async function () {
    await rahatClaimContract.createClaim(
      claimer.address,
      claimee.address,
      otpServer.address,
      token.address
    );
    
    const otpHash = ethers.id('123456')
    await expect(
      rahatClaimContract.connect(otpServer).addOtpToClaim(1, otpHash, Math.floor(Date.now() / 1000) + 3600)
    )
    .to.emit(rahatClaimContract, 'OtpAddedToClaim')
    .withArgs(1);

    const claim = await rahatClaimContract.claims(1);
    expect(claim.otpHash).to.equal(otpHash);
  });

  it('Should process claim', async function () {
    const otpHash = ethers.id('123456')
    const expiryDate = Math.floor(Date.now() / 1000) + 3600;

    await rahatClaimContract.createClaim(
      claimer.address,
      claimee.address,
      otpServer.address,
      token.address
    );

    await rahatClaimContract.connect(otpServer).addOtpToClaim(1, otpHash, expiryDate);

    await expect(
      rahatClaimContract.processClaim(1, '123456')
    )
    .to.emit(rahatClaimContract, 'ClaimProcessed')
    .withArgs(1);

    const claim = await rahatClaimContract.claims(1);
    expect(claim.isProcessed).to.be.true;
  });

  it('Should revert processing claim if OTP is invalid', async function () {
    const otp = '123456';
    const expiryDate = Math.floor(Date.now() / 1000) + 3600;

    await rahatClaimContract.createClaim(
      claimer.address,
      claimee.address,
      otpServer.address,
      token.address
    );

    await rahatClaimContract.connect(otpServer).addOtpToClaim(
      1,
      ethers.id('234234'),
      expiryDate
    );

    await expect(
      rahatClaimContract.processClaim(1, otp)
    ).to.be.revertedWith('invalid otp');
  });

  it('Should revert processing claim if OTP is expired', async function () {
    const otp = '123456';
    const otpHash = ethers.id(otp);

    await rahatClaimContract.createClaim(
      claimer.address,
      claimee.address,
      otpServer.address,
      token.address
    );

    await rahatClaimContract.connect(otpServer).addOtpToClaim(1, otpHash, Math.floor(Date.now() / 1000) - 1);

    await expect(
      rahatClaimContract.processClaim(1, otp)
    ).to.be.revertedWith('expired');
  });

  it('Should revert processing claim if claim is already processed', async function () {
    const otp = '123456';
    const otpHash = ethers.id(otp);
    const expiryDate = Math.floor(Date.now() / 1000) + 3600;

    await rahatClaimContract.createClaim(
      claimer.address,
      claimee.address,
      otpServer.address,
      token.address
    );

    await rahatClaimContract.connect(otpServer).addOtpToClaim(1, otpHash, expiryDate);
    await rahatClaimContract.processClaim(1, otp);

    await expect(
      rahatClaimContract.processClaim(1, otp)
    ).to.be.revertedWith('already processed');
  });
});
