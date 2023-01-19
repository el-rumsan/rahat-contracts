//SPDX-License-Identifier: LGPL-3.0
pragma solidity ^0.8.17;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '../interfaces/IRahatClaim.sol';
import '../interfaces/IRahatProject.sol';
import '../interfaces/IRahatCommunity.sol';

contract RahatCommunity is IRahatCommunity, AccessControl {
  using EnumerableSet for EnumerableSet.AddressSet;
  // #region ***** Events *********//
  event ProjectRequested(address indexed requestor, address indexed project);
  event ProjectAdded(address indexed requestor, address indexed project);
  event ProjectRemoved(address indexed requestor, address indexed project);

  event BeneficiaryAdded(address indexed);
  event BeneficiaryRemoved(address indexed);
  // #endregion

  // #region ***** Variables *********//
  string public name;

  mapping(address => bool) public override isBeneficiary;
  mapping(address => bool) public override projects;

  EnumerableSet.AddressSet private projects;

  bytes32 private constant VENDOR_ROLE = keccak256('VENDOR');
  // #endregion

  // #region ***** Modifiers *********//
  modifier OnlyAdmin() {
    require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'Not an admin');
    _;
  }

  // #endregion

  constructor(string memory _name, address _admin) {
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _setRoleAdmin(VENDOR_ROLE, DEFAULT_ADMIN_ROLE);
    name = _name;
  }

  // #region ***** Role functions *********//
  function isAdmin(address _address) public view returns (bool) {
    return hasRole(DEFAULT_ADMIN_ROLE, _address);
  }

  function addBeneficiary(address _address) public OnlyAdmin {
    isBeneficiary[_address] = true;
    emit BeneficiaryAdded(_address);
  }

  function removeBeneficiary(address _address) public OnlyAdmin {
    isBeneficiary[_address] = false;
    emit BeneficiaryRemoved(_address);
  }

  // #endregion

  // #region ***** Project functions *********//
  function projectCount() public view returns (uint256) {
    return projects.length();
  }

  function projectExists(address _projectAddress) public view returns (bool) {
    return projects.contains(_projectAddress);
  }

  function addProject(address _projectAddress) public OnlyAdmin {
    projects.add(_projectAddress);
  }

  function removeProject(address _projectAddress) public OnlyAdmin {
    projects.remove(_projectAddress);
  }

  function requestToAddProject(address _projectAddress) public {
    emit ProjectRequested(tx.origin, _projectAddress);
  }

  function listProjects(
    uint start,
    uint limit
  ) public view returns (address[] memory _addresses) {
    for (uint i = 0; i < limit; i++) {
      _addresses[i] = (projects.at(start + i));
    }
  }
  // #endregion
}
