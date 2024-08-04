// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { HatsModule } from "hats-module/HatsModule.sol";
import { HatsEligibilityModule } from "hats-module/HatsEligibilityModule.sol";
import { Test, console2 } from "forge-std/Test.sol";

/**
 * @notice Eligibility module that chains any amount of eligibility modules with "and" & "or" logical operations.
 * Modules are chained in a format of a disjunction of conjunction clauses. For example, (module1 && module2) || module3
 * has 2 conjunction clauses: (module1 && module2), module3. These clauses are chained together with an "or" operation.
 * Eligibility is derived according to these logical operations. However, if a wearere is in a bad standing according to
 * any one of the modules, then the module will return a result of not eligble and is in bad standing.
 */
contract HatsEligibilitiesChain is HatsEligibilityModule {
  uint256 internal numConjunctionClauses;
  uint256[] internal conjunctionClauseLengths;
  address[] internal modules;

  error Hi();
  /*//////////////////////////////////////////////////////////////
                          PUBLIC  CONSTANTS
  //////////////////////////////////////////////////////////////*/

  /**
   * This contract is a clone with immutable args, which means that it is deployed with a set of
   * immutable storage variables (ie constants). Accessing these constants is cheaper than accessing
   * regular storage variables (such as those set on initialization of a typical EIP-1167 clone),
   * but requires a slightly different approach since they are read from calldata instead of storage.
   *
   * Below is a table of constants and their locations. In this module, all are inherited from HatsModule.
   *
   * For more, see here: https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args
   *
   * ------------------------------------------------------------------------------------------------------------------+
   * CLONE IMMUTABLE "STORAGE"                                                                                         |
   * ------------------------------------------------------------------------------------------------------------------|
   * Offset                          | Constant                  | Type      | Length                     | Source     |
   * -----------------------------------------------------------------------------------------------------|------------|
   * 0                               | IMPLEMENTATION            | address   | 20                         | HatsModule |
   * 20                              | HATS                      | address   | 20                         | HatsModule |
   * 40                              | hatId                     | uint256   | 32                         | HatsModule |
   * 72                              | NUM_CONJUNCTION_CLAUSES    | uint256   | 32                         | this       |
   * 104                             | CONJUNCTION_CLAUSE_LENGTHS | uint256[] | NUM_CONJUNCTION_CLAUSES* 32 | this       |
   * 104+(NUM_CONJUNCTION_CLAUSES*32) | MODULES                   | address[] | NUM_MODULES * 20           | this       |
   * ------------------------------------------------------------------------------------------------------------------+
   */

  /**
   * @notice Get the number of conjunction clauses
   */
  function NUM_CONJUNCTION_CLAUSES() public view returns (uint256) {
    return numConjunctionClauses;
  }
  // Add setup that sets these as globale variable s in the contract

  /**
   * @notice Get the a list of the lengths of every conjusction clause.
   */
  function CONJUNCTION_CLAUSE_LENGTHS() public view returns (uint256[] memory) {
    return conjunctionClauseLengths;
  }

  /**
   * @notice Get all module addresses.
   */
  function MODULES() public view returns (address[] memory) {
    return modules;
  }

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploy the HatsEligibilitiesChain implementation contract and set its version
   * @dev This is only used to deploy the implementation contract, and should not be used to deploy clones
   */
  constructor(string memory _version, address _hat, uint256 _hatId) HatsModule(_version, _hat, _hatId) { }

  /*//////////////////////////////////////////////////////////////
                      HATS ELIGIBILITY FUNCTION
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the wearer's status.
   */
  function getWearerStatus(address _wearer, uint256 _hatId)
    public
    view
    virtual
    override
    returns (bool eligible, bool standing)
  {
    uint256 numClauses = NUM_CONJUNCTION_CLAUSES();
    bool eligibleInClause;
    bool eligibleInModule;
    bool standingInModule;

    uint256 moduleIdx = 0;
    uint256 clauseIdx = 0;
    console2.logString("Hi");
    standing = true;
    for (uint256 i = 0; i < numConjunctionClauses; i++) {
      eligibleInClause = true;
      console2.logString("Hi 1");
      for (uint256 lenIdx = 0; lenIdx < conjunctionClauseLengths[i]; lenIdx++) {
        address module = modules[moduleIdx];
        moduleIdx++;
        console2.logString("Hi 2");
        (eligibleInModule, standingInModule) = HatsEligibilityModule(module).getWearerStatus(_wearer, _hatId);
        console2.logString("Hi 3");
        console2.logBool(eligibleInModule);
        console2.logBool(standingInModule);
        // bad standing in module -> wearer is not eligible and is in bad standing
        if (!standingInModule) {
          return (false, false);
        }
        /* 
        not eligible in module -> not eligible in clause. Continue checking the next modules in the 
                      clause in order to check the standing status.
                      */
        console2.logString("Hi 4");
        if (eligibleInClause && !eligibleInModule) {
          eligibleInClause = false;
          console2.logString("Hi 5");
        }
      }
      clauseIdx++;
      // if eligible, continue to check only standing
      if (eligibleInClause) {
        eligible = true;
        break;
      }
    }

    for (uint256 i = clauseIdx; i < numConjunctionClauses; i++) {
      for (uint256 lenIdx = 0; lenIdx < conjunctionClauseLengths[i]; lenIdx++) {
        address module = modules[moduleIdx];
        moduleIdx++;
        (, standingInModule) = HatsEligibilityModule(module).getWearerStatus(_wearer, _hatId);
        console2.logString("Hi 3");
        console2.logBool(eligibleInModule);
        console2.logBool(standingInModule);
        // bad standing in module -> wearer is not eligible and is in bad standing
        if (!standingInModule) {
          return (false, false);
        }
      }
    }

    // for (uint256 i = clauseIdx; i < numConjunctionClauses; i++) {
    //   for (uint256 lenIdx = moduleIdx; lenIdx < modules.length; lenIdx++) {
    //     address module = modules[moduleIdx];
    //     (eligibleInModule, standingInModule) = HatsEligibilityModule(module).getWearerStatus(_wearer, _hatId);
    // console2.logString("Hi 6");
    // console2.logBool(standingInModule);
    //     // bad standing in module -> wearer is not eligible and is in bad standing
    //     if (!standingInModule) {
    //       return (false, false);
    //     }
    //   }
    //   standing = true;
    // }
  }

  function _setUp(bytes calldata _initData) internal override {
    (uint256 _numConjunctionClauses, uint256[] memory _conjunctionClauseLengths, bytes memory _modules) =
      abi.decode(_initData, (uint256, uint256[], bytes));
    numConjunctionClauses = _numConjunctionClauses;
    conjunctionClauseLengths = _conjunctionClauseLengths;

    uint256 correctLength = _modules.length % 32;
    uint256 numModules = _modules.length / 32;
    if (correctLength != 0) {
      revert Hi();
    }

    uint256 startIdx = _initData.length - _modules.length;
    for (uint256 i = 0; i < numModules; i++) {
      //console2.logBytes20(bytes20(_initData[(startIdx + (i * 32) +12):(startIdx +(i + 1)*32)]));
      modules.push(address(bytes20(_initData[(startIdx + (i * 32) + 12):(startIdx + (i + 1) * 32)])));
    }
  }
}
