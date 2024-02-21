//SPDX-License_Identifier: LGPL-3.0

pragma solidity 0.8.23;

import '../../interfaces/IELProject.sol';
import '../../libraries/AbstractProject.sol';
import '../../interfaces/IRahatClaim.sol';
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

contract ELProject is AbstractProject, IELProject, ERC2771Context {
    
    using EnumerableSet for EnumerableSet.AddressSet;

    event ClaimAssigned(address indexed beneficiary,address tokenAddress);
    event ClaimProcessed(address indexed beneficiary,address indexed vendor, address indexed token);

    event VendorAllowance(address indexed vendor, address indexed token );
    event VendorAllowanceAccept(address indexed vendor, address indexed token);
    event OtpServerUpdated(address indexed newaddress);
    event TokenRedeem(address indexed _vendorAddress, address indexed _tokenAddress, uint256 _amount);
    event BeneficiaryReferred(address indexed _referrerVendor, address indexed _referrerBeneficiaries, address beneficiaryAddress);
    event ReferredBeneficiaryRemoved(address indexed _benAddress, address _removedBy);

    bytes4 public constant IID_RAHAT_PROJECT = type(IELProject).interfaceId;

    EnumerableSet.AddressSet internal _referredBeneficiaries;


    address public  defaultToken;
    
    address public referredToken;

    address public otpServerAddress;

    uint256 public eyeVoucherAssigned;

    uint256 public referredVoucherAssigned;

    uint256 public eyeVoucherClaimed;
    
    uint256 public referredVoucherClaimed;

    IRahatClaim public RahatClaim;

 

    mapping(address => ReferredBeneficiaries) public referredBenficiaries;

    constructor(string memory _name, address _defaultToken, address _referredToken, address _rahatClaim, address _otpServerAddress, address _forwarder) AbstractProject(_name,msg.sender) ERC2771Context(_forwarder){
        defaultToken = _defaultToken;
        referredToken = _referredToken;
        RahatClaim = IRahatClaim(_rahatClaim); 
        otpServerAddress = _otpServerAddress;
        registerToken(_defaultToken);
        registerToken(_referredToken);
    }


    mapping(address => address) public  beneficiaryEyeVoucher; // beneaddress => tokenAddress

    mapping(address => address) public beneficiaryReferredVoucher; // beneaddress => tokenAddress

    mapping(address => uint256) public eyeVoucherRedeemedByVendor;

    mapping(address => uint256) public referredVoucherRedeemedByVendor;

    mapping(address => mapping(address => bool)) public beneficiaryClaimStatus;

    mapping(address => mapping(address => uint)) public tokenRequestIds; //vendorAddress =>benAddress=>requestId

    mapping(address => bool) public  _registeredTokens;



    // region *****Beneficiary Functions *****//
    
    function addBeneficiary(address _address ) public onlyOpen() onlyAdmin(msg.sender){
        _addBeneficiary(_address);
    }

    function removeBeneficiary(address _address) public onlyOpen() onlyAdmin(msg.sender) {
        _removeBeneficiary(_address);
    }

    function updateAdmin(address _admin,bool _status) public onlyOpen() onlyAdmin(msg.sender){
        _updateAdmin(_admin,_status);
    }

    function updateVendor(address _address, bool _status) public onlyOpen() onlyAdmin(msg.sender){
        _updateVendorStatus(_address, _status);
    }

    function addReferredBeneficiaries(address _account, address _benAddress, address _vendorAddress) public {
        require(_beneficiaries.contains(_benAddress),'referrer ben not registered');
        require(checkVendorStatus(_vendorAddress),'vendor not approved');
        referredBenficiaries[_account] = ReferredBeneficiaries({
            account:_account,
            referrerVendor: _vendorAddress,
            referrerBeneficiaries: _benAddress
        });
        _referredBeneficiaries.add(_account);
        emit BeneficiaryReferred(_vendorAddress, _benAddress, _account);
    }

    function removeReferredBeneficiaries(address _account) public {
        require(_referredBeneficiaries.contains(_account),'referrer ben not registered');
        referredBenficiaries[_account] = ReferredBeneficiaries({
            account:address(0),
            referrerVendor: address(0),
            referrerBeneficiaries: address(0)
        });
        _referredBeneficiaries.remove(_account);
        emit ReferredBeneficiaryRemoved(_account, msg.sender);
    }

    function assignClaims(address _claimerAddress) public override onlyOpen() onlyRegisteredToken(defaultToken){
        _addBeneficiary(_claimerAddress);
        _assignClaims(_claimerAddress, defaultToken,eyeVoucherAssigned); 
        eyeVoucherAssigned++;
        beneficiaryEyeVoucher[_claimerAddress] = defaultToken;
    }

    function assignRefereedClaims(address _claimerAddress,address _refereedToken) public override onlyOpen() onlyRegisteredToken(_refereedToken){        
        require(_referredBeneficiaries.contains(_claimerAddress),'claimer not referred');
        _assignClaims(_claimerAddress,_refereedToken,referredVoucherAssigned);
        referredVoucherAssigned++;
        beneficiaryReferredVoucher[_claimerAddress] = _refereedToken;
    }

    function _assignClaims(address _beneficiary, address _tokenAddress, uint256 _tokenAssigned) private {
        uint256 remainingBudget = tokenBudget(_tokenAddress);
        require(remainingBudget > _tokenAssigned,'token budget exceed');
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

    function increaseTokenBudget(uint256 _amount, address _tokenAddress) onlyOpen() onlyAdmin(msg.sender) public override{
        uint256 budget = tokenBudget(_tokenAddress);
        require(IERC20(_tokenAddress).totalSupply()>= budget+_amount);
        _tokenBudgetIncrease(_tokenAddress, _amount);
    }

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

    function updateOtpServer(address _address) onlyOpen() public {
        require(_address != address(0), 'invalid address');
        require(_address != address(this), 'cannot be contract address');
        require(_address != address(otpServerAddress), 'no change');
        otpServerAddress = _address;
        emit OtpServerUpdated(_address);
    }

    function closeProject() public onlyOpen() {
        close();
    }

    function redeemTokenByVendor(address _tokenAddress, uint256 _amount,address _vendorAddress) onlyOpen() public {
        require(IERC20(_tokenAddress).balanceOf(_vendorAddress) >= _amount,'Insufficient balance' );
        // require(IERC20(_tokenAddress).approve(address(this),_amount),'approve failed');
        // require(IERC20(_tokenAddress).transferFrom(_vendorAddress,address(this),_amount),'transfer failed');
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
