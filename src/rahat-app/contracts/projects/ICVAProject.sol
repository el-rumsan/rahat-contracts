//SPDX-License-Identifier: LGPL-3.0
pragma solidity 0.8.23;

import '../../interfaces/IRahatProject.sol';

interface ICVAProject is IRahatProject {
  ///@dev Project's default token
  function defaultToken() external returns (address);

  function otpServerAddress() external returns (address);

  function isDonor(address _address) external returns (bool);

  function beneficiaryClaims(address _address) external returns (uint);

  ///@dev Add beneficiary to project with claim amount;
  function assignClaims(address _address, uint _claimAmount) external;

  function totalClaimsAssgined() external view returns (uint _totalClaims);

  ///@dev Accept Tokens from Rahatdonor by projectManager(communityManager)
  ///@dev Save the received token in a set.
  ///@dev Save the no. of tokens issued to track total tokens received
  function acceptToken(address _from, uint _amount) external;

  function withdrawToken(address _token) external;

  function createAllowanceToVendor(address _address, uint256 _amount) external;

  function acceptAllowanceByVendor(uint256 _amount) external;

  ///@dev Request For tokens From Beneficay by vendor
  function requestTokenFromBeneficiary(
    address _benAddress,
    uint _amount
  ) external returns (uint requestId);

  function requestTokenFromBeneficiary(
    address _benAddress,
    uint _amount,
    address _otpServerAddress
  ) external returns (uint requestId);

  ///@dev Process token request to beneficiary by otp verfication
  function processTokenRequest(address _benAddress, string memory _otp) external;

  function updateOtpServer(address _address) external;
}
