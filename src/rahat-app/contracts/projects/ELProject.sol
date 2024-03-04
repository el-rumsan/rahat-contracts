//SPDX-License_Identifier: LGPL-3.0

pragma solidity 0.8.23;

import '../../interfaces/IELProject.sol';
import '../../libraries/AbstractProject.sol';
import '../../interfaces/IRahatClaim.sol';
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

/// @title ELProject - Implementation of IELProject interface
/// @notice This contract implements the IELProject interface and provides functionalities for managing beneficiaries, claims, and referrals.
/// @dev This contract uses the ERC2771Context for meta-transactions and extends AbstractProject for basic project functionality.
contract ELProject is AbstractProject, IELProject, ERC2771Context {
    
    using EnumerableSet for EnumerableSet.AddressSet;

    //Events
    event ClaimRevert(address indexed beneficiary, address tokenAddress);
    event ClaimAssigned(address indexed beneficiary,address tokenAddress,address assigner);
    event ClaimProcessed(address indexed beneficiary,address indexed vendor, address indexed token);
    event VendorAllowance(address indexed vendor, address indexed token );
    event VendorAllowanceAccept(address indexed vendor, address indexed token);
    event OtpServerUpdated(address indexed newaddress);
    event TokenRedeem(address indexed _vendorAddress, address indexed _tokenAddress, uint256 _amount);
    event BeneficiaryReferred(address indexed _referrerVendor, address indexed _referrerBeneficiaries, address beneficiaryAddress);
    event ReferredBeneficiaryRemoved(address indexed _benAddress, address _removedBy);

    /// @dev Interface ID for IELProject
    bytes4 public constant IID_RAHAT_PROJECT = type(IELProject).interfaceId;

    /// @dev address list for referred beneficiaries
    EnumerableSet.AddressSet internal _referredBeneficiaries;

    /// @dev address of default token(free voucher address)
    address public  defaultToken;
    
    /// @dev address of referredToken(discount voucher address)
    address public referredToken;

    /// @dev address responsible for generating otp required during voucher claim
    address public otpServerAddress;

    /// @dev tracks total number of default voucher assigned to beneficiaries
    uint256 public eyeVoucherAssigned;

    /// @dev tracks total number of referred voucher assigned to beneficiaries

    uint256 public referredVoucherAssigned;

    uint256 public eyeVoucherReverted;

    uint256 public referredVoucherReverted;

    /// @dev tracks total number of default voucher claimed by beneficiaries
    uint256 public eyeVoucherClaimed;

    /// @dev tracks total number of referred voucher claimed by beneficiaries
    uint256 public referredVoucherClaimed;

    /// @dev maximum number of beneficiaries that can be referred
    uint256 public  referralLimit;

    /// @dev instance of rahat claim
    IRahatClaim public RahatClaim;

    /// @dev key-value pair of referred beneficiaries to details
    mapping(address => ReferredBeneficiaries) public referredBenficiaries;

    /// @notice tracks whether free voucher is assigned to the beneficiaries or not
    ///@dev key-value pair of beneficiaries and free voucher address
    mapping(address => address) public  beneficiaryEyeVoucher; // beneaddress => tokenAddress

    
    /// @notice tracks referred voucher is assigned to the beneficiaries
    ///@dev key-value pair of beneficiaries and referred voucher address
    mapping(address => address) public beneficiaryReferredVoucher; // beneaddress => tokenAddress

    /// @notice tracks the number of free voucher redeemed by vendor
    ///@dev key-value pair of vendor address and number of free voucher redeemed
    mapping(address => uint256) public eyeVoucherRedeemedByVendor;

    /// @notice tracks the number of referred voucher redeemed by vendor
    ///@dev key-value pair of vendor address and number of referred voucher redeemed
    mapping(address => uint256) public referredVoucherRedeemedByVendor;

    /// @notice tracks the number of beneficiary referred by vendor
    ///@dev key-value pair of vendor address and number of beneficiary referred
    mapping(address =>uint256) public beneficiaryReferredByVendor;//venAddress =>totalnumber

    /// @notice tracks the number of beneficiary referred by beneficiary
    ///@dev key-value pair of beneficiary address and number of beneficiary referred
    mapping(address =>uint256) public beneficiaryReferredByBeneficiary;

    /// @notice tracks whether the particular voucher is claimed by beneficiary or not
    ///@dev key-value pair of beneficiary address and voucher claim status
    mapping(address => mapping(address => bool)) public beneficiaryClaimStatus;

    /// @notice tracks voucher claim request Id
    ///@dev key-value pair of vendor address and voucher claim request id for given beneficiaries
    mapping(address => mapping(address => uint)) public tokenRequestIds; //vendorAddress =>benAddress=>requestId

    /// @notice tracks the registered token address
    /// @dev key-value pair of voucher address and registered status
    mapping(address => bool) public  registeredTokens;


    ///@notice constructor
    ///@param _name name of the project
    ///@param _defaultToken address of the default voucher(ERC20)
    ///@param _referredToken address of the referred voucher(ERC20)
    ///@param _rahatClaim address of the rahat claim contract voucher
    ///@param _otpServerAddress address responsible for otp
    ///@param _forwarder address of the forwarder contract
    ///@param _referralLimit limits for referral
    constructor(string memory _name, address _defaultToken, address _referredToken, address _rahatClaim, address _otpServerAddress, address _forwarder,uint256 _referralLimit) AbstractProject(_name,msg.sender) ERC2771Context(_forwarder){
        defaultToken = _defaultToken;
        referredToken = _referredToken;
        RahatClaim = IRahatClaim(_rahatClaim); 
        otpServerAddress = _otpServerAddress;
        registerToken(_defaultToken);
        registerToken(_referredToken);
        referralLimit = _referralLimit;
    }
    
    // region *****Beneficiary Functions *****//
    ///@notice function to add beneficiaries
    ///@param _address address of the beneficiary
    ///@dev can only be called by project admin when project is open
    function addBeneficiary(address _address ) public onlyOpen() onlyAdmin(msg.sender){
        _addBeneficiary(_address);
    }
    ///@notice function to remove beneficiaries
    ///@param _address address of the beneficiary to be removed
    ///@dev can only be called by project admin when project is open
    function removeBeneficiary(address _address) public onlyOpen() onlyAdmin(msg.sender) {
        _removeBeneficiary(_address);
    }


    ///@notice function to add status of  admin role
    ///@param _admin address of the admin
    ///@param _status boolean value for admin role
    ///@dev can only be called by project admin when project is open
    function updateAdmin(address _admin,bool _status) public onlyOpen() onlyAdmin(msg.sender){
        _updateAdmin(_admin,_status);
    }

    ///@notice function to update the status of  vendor
    ///@param _address address of the vendor
    ///@param _status boolean value for vendor role
    ///@dev can only be called by project admin when project is open
    function updateVendor(address _address, bool _status) public onlyOpen() onlyAdmin(msg.sender){
        _updateVendorStatus(_address, _status);
    }

    ///@notice function to add reffered beneficiaries
    ///@param _account address of the beneficiary
    ///@param _benAddress address of referral beneficairy(referral- one referring the new beneficairy)
    ///@param _vendorAddress address of referral vendor
    ///@dev can only be called by project vendors when project is open
    function addReferredBeneficiaries(address _account, address _benAddress, address _vendorAddress) public onlyOpen(){
        require(_beneficiaries.contains(_benAddress),'referrer ben not registered');
        require(checkVendorStatus(_vendorAddress),'vendor not approved');
        require(beneficiaryReferredByBeneficiary[_benAddress] <= referralLimit,'referral:limit hit');
        referredBenficiaries[_account] = ReferredBeneficiaries({
            account:_account,
            referrerVendor: _vendorAddress,
            referrerBeneficiaries: _benAddress
        });
        _referredBeneficiaries.add(_account);
        beneficiaryReferredByBeneficiary[_benAddress]++;
        beneficiaryReferredByVendor[_vendorAddress] ++;
        emit BeneficiaryReferred(_vendorAddress, _benAddress, _account);
    }

    ///@notice function to remove referred beneficiaries
    ///@param _account address of the beneficiary
    ///@dev can only be called by project admin when project is open
    function removeReferredBeneficiaries(address _account) public onlyOpen() onlyAdmin(msg.sender) {
        require(_referredBeneficiaries.contains(_account),'referrer ben not registered');
        referredBenficiaries[_account] = ReferredBeneficiaries({
            account:address(0),
            referrerVendor: address(0),
            referrerBeneficiaries: address(0)
        });
        _referredBeneficiaries.remove(_account);
        emit ReferredBeneficiaryRemoved(_account, msg.sender);
    }

    /// @notice function to assign free voucher/claims to beneficiaries
    ///@param _claimerAddress address of beneficiaires to assign claims
    ///@dev can only be called by project admin when project is open and voucher should be registered to project
    function assignClaims(address _claimerAddress) public override onlyOpen() onlyRegisteredToken(defaultToken) onlyAdmin(msg.sender){
        _addBeneficiary(_claimerAddress);
        _assignClaims(_claimerAddress, defaultToken,eyeVoucherAssigned,msg.sender); 
        eyeVoucherAssigned++;
        beneficiaryEyeVoucher[_claimerAddress] = defaultToken;
    }

    /// @notice function to assign referred voucher/claims to beneficiaries
    ///@param _claimerAddress address of beneficiaires to assign claims
    ///@param _refereedToken address of referred voucher
    ///@dev can only be called by project vendors when project is open and voucher should be registered to project
    function assignRefereedClaims(address _claimerAddress,address _refereedToken) public override onlyOpen() onlyRegisteredToken(_refereedToken){        
        require(_referredBeneficiaries.contains(_claimerAddress),'claimer not referred');
        require(checkVendorStatus(msg.sender),'vendor not approved');
        _assignClaims(_claimerAddress,_refereedToken,referredVoucherAssigned,msg.sender);
        referredVoucherAssigned++;
        beneficiaryReferredVoucher[_claimerAddress] = _refereedToken;
    }

    ///@notice function to revert unclaimed vouchers
    ///@param _claimerAddress address of beneficiaires to revert claim
    function revertedClaims(address _claimerAddress) public onlyOpen() onlyRegisteredToken(defaultToken){
        require(beneficiaryEyeVoucher[_claimerAddress] == defaultToken, "Token not assigned");
        eyeVoucherReverted++;
        emit ClaimRevert(_claimerAddress, defaultToken);
    }
  
    ///@notice function to revert unclaimed vouchers of other tokens
    ///@param _claimerAddress address of beneficiaires to revert claim
    ///@param _refereedToken address of token to be reverted
    function revertedRefereedClaims(address _claimerAddress,address _refereedToken) public onlyOpen() onlyRegisteredToken(_refereedToken){        
        require(beneficiaryReferredVoucher[_claimerAddress] == _refereedToken,'Token not assigned');
        referredVoucherAssigned++;
        emit ClaimRevert(_claimerAddress, _refereedToken);
    }

 
    ///@notice internal function to assign  voucher/claims to beneficiaries
    ///@param _beneficiary address of beneficiaires to assign claims
    ///@param _tokenAddress address of the voucher to assign
    ///@param _tokenAssigned amount of token assigned till date
    ///@dev internal function to assign claims
    function _assignClaims(address _beneficiary, address _tokenAddress, uint256 _tokenAssigned,address _assigner) private {
        uint256 remainingBudget = tokenBudget(_tokenAddress);
        require(remainingBudget > _tokenAssigned,'token budget exceed');
        emit ClaimAssigned(_beneficiary, _tokenAddress,_assigner);

    }

    ///@notice function to request free voucher claim process
    ///@param _benAddress address of beneficiary
    ///@dev can be called only when project is open
    function requestTokenFromBeneficiary(address _benAddress) public onlyOpen() override returns(uint256 requestId){
        require(beneficiaryEyeVoucher[_benAddress] == defaultToken,'eye voucher not assigned');
        requestId = requestTokenFromBeneficiary(_benAddress, defaultToken,otpServerAddress);
    }

    ///@notice function to request referred voucher claim process
    ///@param _benAddress address of beneficiary
    ///@param _tokenAddress address of referred voucher
    ///@dev can be called only when project is open
    function requestReferredTokenFromBeneficiary(address _benAddress, address _tokenAddress) public override onlyOpen() returns(uint256 requestId){
        require(beneficiaryReferredVoucher[_benAddress] == _tokenAddress,'referred voucher not assigned');
        requestId = requestTokenFromBeneficiary(_benAddress, _tokenAddress,otpServerAddress);
    }

    ///@notice  function to request  voucher claim process
    ///@param _benAddress address of beneficiary
    ///@param _tokenAddress address of voucher
    ///@param _otpServer address responsible for otp
    ///@dev can be called only when project is open
    function requestTokenFromBeneficiary(address _benAddress, address _tokenAddress, address _otpServer) public  onlyOpen() returns(uint256 requestId) {
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

    ///@notice function to process token after recieving otp. This is the last step for beneficiary during voucher claim process
    ///@param _benAddress address of the beneficiary
    ///@param _otp otp received by beneficiary
    function processTokenRequest(address _benAddress, string memory _otp)onlyOpen() public{
        IRahatClaim.Claim memory _claim = RahatClaim.processClaim(
            tokenRequestIds[msg.sender][_benAddress],
            _otp
        );
        _transferTokenToClaimer(_claim.tokenAddress, _claim.claimeeAddress,_claim.claimerAddress);

    }
    ///@notice function to increase the tokenBudget
    ///@param _amount amount to increase the budget
    ///@param _tokenAddress address of the voucher to increase budget
    ///@dev can only be called by admin.Mainly called during minting of vouchers
    function increaseTokenBudget(uint256 _amount, address _tokenAddress) onlyOpen() onlyAdmin(msg.sender) public override{
        uint256 budget = tokenBudget(_tokenAddress);
        require(IERC20(_tokenAddress).totalSupply()>= budget+_amount);
        _tokenBudgetIncrease(_tokenAddress, _amount);
    }

    ///@notice internal function called during voucher claim process
    ///@param _tokenAddress address of voucher
    ///@param _benAddress address of beneficiaries(claimer)
    ///@param _vendorAddress address of vendor processing the claim
    ///@dev claimed voucher is transferred to vendor processing the claim
    function _transferTokenToClaimer(address _tokenAddress, address _benAddress, address _vendorAddress) private{
        require(!beneficiaryClaimStatus[_benAddress][_tokenAddress],'voucher already claimed' );
        beneficiaryClaimStatus[_benAddress][_tokenAddress] = true;
        if(_tokenAddress == defaultToken) {eyeVoucherClaimed++;
        eyeVoucherRedeemedByVendor[_vendorAddress]++;
        }
        else {
            referredVoucherClaimed++;
            referredVoucherRedeemedByVendor[_vendorAddress]++;
        
        }
        require(IERC20(_tokenAddress).transfer(_vendorAddress,1),'transfer failed');
        // _tokenBudgetDecrease(_tokenAddress, 1);
        emit ClaimProcessed(_benAddress, _vendorAddress, _tokenAddress);
    }

    ///@notice function to update the otp server
    ///@param _address new address of otp server
    ///@dev only admin can change the otp server address when project is open
    function updateOtpServer(address _address) onlyOpen() public onlyAdmin(msg.sender) {
        require(_address != address(0), 'invalid address');
        require(_address != address(this), 'cannot be contract address');
        require(_address != address(otpServerAddress), 'no change');
        otpServerAddress = _address;
        emit OtpServerUpdated(_address);
    }  

    ///@notice function to close project
    ///@dev can only be called by admin.
    function closeProject() public onlyOpen() onlyAdmin(msg.sender) {
        close();
    }

    ///@notice function to get the vendor related voucher details
    ///@param _vendor address of the vendor
    ///@return voucherDetails struct storing all voucher details
    ///@dev getter function to get all voucher details of vendor
    function getVendorVoucherDetail(address _vendor) public view returns(VoucherDetailByVendor memory voucherDetails){
        voucherDetails = VoucherDetailByVendor({
            freeVoucherRedeemed:  eyeVoucherRedeemedByVendor[_vendor],
            referredVoucherRedeemed : referredVoucherRedeemedByVendor[_vendor],
            beneficiaryReferred : beneficiaryReferredByVendor[_vendor]
            });
        return voucherDetails;

    }

    ///@notice function to get the project voucher details
    ///@return projectVoucherDetails struct storing all voucher details
    ///@dev getter function to get all voucher details of project
    function getProjectVoucherDetail() public view returns(ProjectVoucherDetails memory projectVoucherDetails){
        projectVoucherDetails = ProjectVoucherDetails({
           eyeVoucherAssigned: eyeVoucherAssigned,
            referredVoucherAssigned:referredVoucherAssigned,
            eyeVoucherClaimed:eyeVoucherClaimed,
            referredVoucherClaimed:referredVoucherClaimed,
            eyeVoucherBudget:tokenBudget(defaultToken),
            referredVoucherBudget:tokenBudget(referredToken)
        });

        return projectVoucherDetails;

    }

    ///@notice function to get number of beneficiaries
    ///@return enrolledBen number of enrolled beneficiaries 
    ///@return referredBen number of referred beneficiaries
    function getTotalBeneficiaries() public view returns(uint256 enrolledBen, uint256 referredBen){
        enrolledBen = _beneficiaries.length();
        referredBen = _referredBeneficiaries.length();
        return(enrolledBen,referredBen);

    }

    ///@notice function to redeem token by vendor. Vendor will receive amount equivalent to token amount after redemeption
    ///@param _tokenAddress voucher address
    ///@param _amount amount of voucher to redeem
    ///@param _vendorAddress address of vendor
    function redeemTokenByVendor(address _tokenAddress, uint256 _amount,address _vendorAddress) onlyOpen() public {
        require(IERC20(_tokenAddress).balanceOf(_vendorAddress) >= _amount,'Insufficient balance' );
        IRahatToken(_tokenAddress).burnFrom(_vendorAddress,_amount);
        emit TokenRedeem(_vendorAddress,_tokenAddress,_amount);
    }


    // #endregion
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == IID_RAHAT_PROJECT;
    }


    /// @dev overriding the method to ERC2771Context
    function _msgSender()
        internal
        view
        override(Context, ERC2771Context)
        returns (address sender)
    {
        sender = ERC2771Context._msgSender();
    }

    /// @dev overriding the method to ERC2771Context
    function _msgData()
        internal
        view
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(Context, ERC2771Context)
        returns (uint256)
    {
        return ERC2771Context._contextSuffixLength();
    }
}
