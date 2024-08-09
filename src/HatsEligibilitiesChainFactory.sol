// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IHatsModuleFactory } from "hats-module/interfaces/IHatsModuleFactory.sol";
import { HatsEligibilitiesChain } from "src/HatsEligibilitiesChain.sol";
import { L2ContractHelper } from "./lib/L2ContractHelper.sol";

contract HatsEligibilitiesChainFactory is IHatsModuleFactory {
  string public constant VERSION = "0.6.0-zksync";
  /// @dev Bytecode hash can be found in artifacts-zk/src/HatsEligibilitiesChainFactory.sol/HatsEligibilitiesChainFactory.json under the facotryDeps key.
  bytes32 constant BYTECODE_HASH = 0x0100017f864916aad943214f07be84ecbe29a1d8b69ae77ef4999a126491757f;

  function deployModule(uint256 _hatId, address _hat, bytes calldata _initData, uint256 _saltNonce)
    external
    returns (address)
  {
    bytes memory saltArgs = abi.encodePacked(VERSION, _hatId, _hat, _initData);
    bytes32 salt = _calculateSalt(saltArgs, _saltNonce);
    HatsEligibilitiesChain instance = new HatsEligibilitiesChain{ salt: salt }(VERSION, _hat, _hatId);
    instance.setUp(_initData);
    emit ModuleDeployed(
      address(instance), address(instance), _hatId, abi.encodePacked(_hat, _initData), _initData, _saltNonce
    );
    return address(instance);
  }

  function _calculateSalt(bytes memory _args, uint256 _saltNonce) internal view returns (bytes32) {
    return keccak256(abi.encodePacked(_args, block.chainid, _saltNonce));
  }

  function getAddress(uint256 _hatId, address _hat, bytes calldata _initData, uint256 _saltNonce)
    external
    view
    returns (address addr)
  {
    bytes memory saltArgs = abi.encodePacked(VERSION, _hatId, _hat, _initData);
    bytes32 salt = _calculateSalt(saltArgs, _saltNonce);
    addr = L2ContractHelper.computeCreate2Address(
      address(this), salt, BYTECODE_HASH, keccak256(abi.encode(VERSION, _hat, _hatId))
    );
  }
}
