//SPDX-License-Identifier: LGPL-3.0

pragma solidity 0.8.23;

import '@openzeppelin/contracts/utils/introspection/IERC165.sol';

interface IELProject is IERC165 {

  struct ReferredBeneficiaries{
        address account;
        address referrerVendor;
        address referrerBeneficiaries;
  }

  struct ProjectVoucherDetails{
    uint256 eyeVoucherAssigned;
    uint256 referredVoucherAssigned;
    uint256 eyeVoucherClaimed;
    uint256 referredVoucherClaimed;
    uint256 eyeVoucherBudget;
    uint256 referredVoucherBudget;

  }

  struct VoucherDetailByVendor{
    uint256 freeVoucherRedeemed;
    uint256 referredVoucherRedeemed;
    uint256 beneficiaryReferred;
  }

  struct BeneficiaryVoucherDetails{
    address freeVoucherAddress;
    address referredVoucherAddress;
    bool freeVoucherClaimStatus;
    bool referredVoucherClaimStatus;

  }

  function addBeneficiary(address _address) external;

  function removeBeneficiary(address _address) external;

  // function isBeneficiary(address _address) external view returns (bool);

  // function beneficiaryCount() external view returns (uint256);

  function otpServerAddress() external returns (address);
 
  // function beneficiaryClaims(address _address) external returns (uint);

  ///@dev Add beneficiary to project with claim amount;
  function assignClaims(address _address) external;

  function assignRefereedClaims(address _address, address _referralben, address _referralVendor,address _tokenAddress) external;

  // function totalClaimsAssgined() external view returns (uint _totalClaims);

  //  function withdrawToken(address _token) external;

  // function createAllowanceToVendor(address _address, uint256 _amount) external;

  // function acceptAllowanceByVendor(uint256 _amount) external;

  ///@dev Request For tokens From Beneficay by vendor
  function requestTokenFromBeneficiary(
    address _benAddress) external returns (uint requestId);

    function requestReferredTokenFromBeneficiary(
    address _benAddress,
    address _tokenAddress
  ) external returns (uint requestId);

  // function requestTokenFromBeneficiary(
  //   address _benAddress,
  //   address _tokenAddress,
  //   address _otpServerAddress
  // ) external returns (uint requestId);

  ///@dev Process token request to beneficiary by otp verfication
  function processTokenRequest(address _benAddress, string memory _otp) external;

  function updateOtpServer(address _address) external;

  function increaseTokenBudget(uint256 _amount, address _tokenAddress) external;
}