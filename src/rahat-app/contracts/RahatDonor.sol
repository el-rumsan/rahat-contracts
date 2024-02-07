//SPDX-License-Identifier: LGPL-3.0
pragma solidity 0.8.23;

import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import './RahatToken.sol';
import '../libraries/AbstractTokenActions.sol';
import '../interfaces/IRahatProject.sol';
import '../interfaces/IRahatDonor.sol';
import '../interfaces/IRahatTreasury.sol';

/// @title Donor contract to create tokens
/// @author Rumsan Associates
/// @notice You can use this contract to manage Rahat tokens and projects
/// @dev All function calls are only executed by contract owner
contract RahatDonor is AbstractTokenActions, ERC165 {
  event TokenCreated(address indexed tokenAddress);
  event TokenMintedAndApproved(
    address indexed tokenAddress,
    address indexed approveAddress,
    uint256 amount
  );

  /// @notice All the supply is allocated to this contract
  /// @dev deploys AidToken and Rahat contract by sending supply to this contract

  bytes4 public constant IID_RAHAT_DONOR = type(IRahatDonor).interfaceId;
  mapping(uint256 => uint256) public tokenToDollarValue;

  IRahatTreasury public RahatTreasury;

  constructor(address _admin,address _treasury, uint256 averageDollarValue ) {
    _addOwner(_admin);
    RahatTreasury = IRahatTreasury(_treasury);
    tokenToDollarValue[1] = averageDollarValue;
  }

  //#region Token function
  function createToken(
    string memory _name,
    string memory _symbol,
    uint8 decimals
  ) public OnlyOwner returns (address) {
    RahatToken _token = new RahatToken(_name, _symbol, address(this), decimals);
    address _tokenAddress = address(_token);
    emit TokenCreated(_tokenAddress);
    return _tokenAddress;
  }

  function mintToken(address _token, uint256 _amount) public OnlyOwner {
    RahatToken(_token).mint(address(this), _amount);
  }

  function mintTokenAndApprove(
    address _token,
    address _approveAddress,
    uint256 _amount,
    uint256 _treasuryId
  ) public OnlyOwner {
    require(_token != address(0), 'token address cannot be zero');
    require(_approveAddress != address(0), 'approve address cannot be zero');
    require(_amount > 0, 'amount cannot be zero');
    IRahatTreasury.Treasury  memory _treasury= RahatTreasury.checkBudget(_treasuryId);
    uint256 _totalDollar = tokenToDollarValue[1];
    require(_treasury.budget >= _totalDollar * _amount,"budget amount exceed");
    RahatToken token = RahatToken(_token);
    token.mint(address(this), _amount);
    token.approve(_approveAddress, _amount);
    emit TokenMintedAndApproved(_token, _approveAddress, _amount);
  }


  function addTokenOwner(address _token, address _ownerAddress) public OnlyOwner {
    RahatToken(_token).addOwner(_ownerAddress);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == IID_RAHAT_DONOR || super.supportsInterface(interfaceId);
  }

  //#endregion
}
