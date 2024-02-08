//SPDX-License_Identifier: LGPL-3.0

pragma solidity 0.8.23;

import '../../interfaces/IELProject.sol';
import '../../libraries/AbstractProject.sol';
import '../../interfaces/IRahatClaim.sol';

contract ELProject is AbstractProject, IELProject {
    using EnumerableSet for EnumerableSet.AddressSet;

    event ClaimAssigned(address indexed beneficiary,address tokenAddress);
    event ClaimProcessed(address indexed beneficiary,address indexed vendor, address indexed token);

    event VendorAllowance(address indexed vendor, address indexed token );
    event VendorAllowanceAccept(address indexed vendor, address indexed token);
    event OtpServerUpdated(address indexed newaddress);

    bytes4 public constant IID_RAHAT_PROJECT = type(IELProject).interfaceId;


    address public  defaultToken;
    
    address public referredToken;

    address public otpServerAddress;

    uint256 public eyeVoucherAssigned;

    uint256 public referredVoucherAssigned;

    uint256 public eyeVoucherClaimed;
    
    uint256 public referredVoucherClaimed;
 

    IRahatClaim public RahatClaim;


    constructor(string memory _name, address _defaultToken, address _referredToken, address _rahatClaim, address _otpServerAddress) AbstractProject(_name){
        defaultToken = _defaultToken;
        referredToken = _referredToken;
        RahatClaim = IRahatClaim(_rahatClaim);
        otpServerAddress = _otpServerAddress;
        registerToken(_defaultToken);
        registerToken(_referredToken);
    }


    mapping(address => address) public  beneficiaryEyeVoucher; // beneaddress => tokenAddress

    mapping(address => address) public beneficiaryReferredVoucher; // beneaddress => tokenAddress

    mapping(address => mapping(address => bool)) public beneficiaryTokenStatus;

    mapping(address => mapping(address => bool)) public beneficiaryClaimStatus;

    mapping(address => mapping(address => uint)) public tokenRequestIds; //vendorAddress =>benAddress=>requestId

    mapping(address => bool) public  _registeredTokens;

    // region *****Beneficiary Functions *****//
    
    function addBeneficiary(address _address ) public onlyOpen() {
        _addBeneficiary(_address);
    }

    function removeBeneficiary(address _address) public onlyOpen() {
        _removeBeneficiary(_address);
    }

    function assignClaims(address _claimerAddress) public override onlyOpen() onlyRegisteredToken(defaultToken){
        _addBeneficiary(_claimerAddress);
        _assignClaims(_claimerAddress, defaultToken); 
        eyeVoucherAssigned++;
        beneficiaryEyeVoucher[_claimerAddress] = defaultToken;
    }

    function assignRefereedClaims(address _claimerAddress,address _refereedToken) public override onlyOpen() onlyRegisteredToken(_refereedToken){
        _addBeneficiary(_claimerAddress);
        _assignClaims(_claimerAddress,_refereedToken);
        referredVoucherAssigned++;
        beneficiaryReferredVoucher[_claimerAddress] = _refereedToken;
    }

    function _assignClaims(address _beneficiary, address _tokenAddress) private {
        // require(IERC20(_tokenAddress).balanceOf(address(this))>= referredVoucherClaimed() + 1,
        // "not enough tokens");
        beneficiaryTokenStatus[_beneficiary][_tokenAddress] = true;
        emit ClaimAssigned(_beneficiary, _tokenAddress);

    }

    function requestTokenFromBeneficiary(address _benAddress) public onlyOpen() override returns(uint256 requestId){
        require(beneficiaryEyeVoucher[_benAddress] == defaultToken,'eye voucher not assigned');
        requestId = requestTokenFromBeneficiary(_benAddress, defaultToken,otpServerAddress);
    }

    function requestReferredTokenFromBeneficiary(address _benAddress, address _tokenAddress) public override onlyOpen() returns(uint256 requestId){
        require(beneficiaryReferredVoucher[_benAddress] == _tokenAddress,'referred voucher not assigned');
        requestId = requestTokenFromBeneficiary(_benAddress, _tokenAddress,otpServerAddress);
    }

    function requestTokenFromBeneficiary(address _benAddress, address _tokenAddress, address _otpServer) public onlyOpen() returns(uint256 requestId) {
        require(otpServerAddress != address(0), 'invalid otp-server');
        require(!beneficiaryClaimStatus[_benAddress][_tokenAddress],'Voucher already claimed');
        //need to check total budget

        requestId = RahatClaim.createClaim(
            msg.sender,
            _benAddress,
            _otpServer,
            _tokenAddress);
        tokenRequestIds[msg.sender][_benAddress] = requestId;
        return requestId;
    }

    function processTokenRequest(address _benAddress, string memory _otp)onlyOpen() public{
        IRahatClaim.Claim memory _claim = RahatClaim.processClaim(
            tokenRequestIds[msg.sender][_benAddress],
            _otp
        );
        _transferTokenToClaimer(_claim.tokenAddress, _claim.claimeeAddress,_claim.claimerAddress);

    }

    function _transferTokenToClaimer(address _tokenAddress, address _benAddress, address _vendorAddress) private{
        require(!beneficiaryClaimStatus[_benAddress][_tokenAddress],'voucher already claimed' );
        beneficiaryClaimStatus[_benAddress][_tokenAddress] = true;
        if(_tokenAddress == defaultToken) eyeVoucherClaimed++;
        else referredVoucherClaimed++;
        require(IERC20(_tokenAddress).transfer(_vendorAddress,1),'transfer failed');
        emit ClaimProcessed(_benAddress, _vendorAddress, _tokenAddress);
    }

    function updateOtpServer(address _address) onlyOpen() public {
        require(_address != address(0), 'invalid address');
        require(_address != address(this), 'cannot be contract address');
        require(_address != address(otpServerAddress), 'no change');
        otpServerAddress = _address;
        emit OtpServerUpdated(_address);
    }

    function closeProject() public onlyOpen(){
        close();
    }

    // #endregion
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == IID_RAHAT_PROJECT;
        }
        // return interfaceId == IID_RAHAT_PROJECT;
}
