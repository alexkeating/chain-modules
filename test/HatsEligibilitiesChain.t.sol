// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import { HatsEligibilitiesChain } from "src/HatsEligibilitiesChain.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { Hats } from "hats-protocol/Hats.sol";
import {
  TestEligibilityAlwaysEligible,
  TestEligibilityAlwaysNotEligible,
  TestEligibilityAlwaysBadStanding,
  TestEligibilityOnlyBadStanding
} from "./utils/TestModules.sol";
import { HatsEligibilityModule } from "hats-module/HatsEligibilityModule.sol";
import { IHatsModuleFactory } from "hats-module/interfaces/IHatsModuleFactory.sol";
import { HatsModule } from "hats-module/HatsModule.sol";
import { HatsEligibilitiesChain } from "src/HatsEligibilitiesChain.sol";
import { HatsEligibilitiesChainFactory } from "src/HatsEligibilitiesChainFactory.sol";

contract DeployImplementationTest is Test {
  uint256 public fork;
  uint256 public BLOCK_NUMBER = 9_395_052; // the block number where hats module factory was deployed on Goerli;

  string public constant version = "0.6.0-zksync";
  // IHats public constant HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth
  string internal constant x = "Hats Protocol v1";
  string internal constant y = "";
  IHats public HATS = new Hats{ salt: bytes32(abi.encode(0x4a75)) }(x, y);
  IHatsModuleFactory public FACTORY;

  HatsEligibilitiesChain public instance;
  uint256 public tophat;
  uint256 public chainedEligibilityHat;
  address public eligibility = makeAddr("eligibility");
  address public toggle = makeAddr("toggle");
  address public dao = makeAddr("dao");
  address public wearer = makeAddr("wearer");

  uint256[] clauseLengths;
  address module1;
  address module2;
  address module3;

  address[] expectedModules;

  uint256 saltNonce = 1;

  function deployInstanceTwoModules(
    uint256 targetHat,
    uint256 numClauses,
    uint256[] memory lengths,
    address _module1,
    address _module2
  ) public returns (HatsEligibilitiesChain) {
    address[2] memory modules = [_module1, _module2];
    bytes memory otherImmutableArgs = abi.encode(numClauses, lengths, abi.encode(modules));
    // deploy the instance
    // return HatsEligibilitiesChain(
    //   deployModuleInstance(FACTORY, address(instance), targetHat, otherImmutableArgs, "", saltNonce)
    // );
    console2.logBytes(otherImmutableArgs);
    return HatsEligibilitiesChain(FACTORY.deployModule(targetHat, address(HATS), otherImmutableArgs, saltNonce));
  }

  function deployInstanceThreeModules(
    uint256 targetHat,
    uint256 numClauses,
    uint256[] memory lengths,
    address _module1,
    address _module2,
    address _module3
  ) public returns (HatsEligibilitiesChain) {
    address[3] memory modules = [module1, _module2, _module3];
    bytes memory otherImmutableArgs = abi.encode(numClauses, lengths, abi.encode(modules));
    return HatsEligibilitiesChain(FACTORY.deployModule(targetHat, address(HATS), otherImmutableArgs, saltNonce));
  }

  function setUp() public virtual {
    // create and activate a fork, at BLOCK_NUMBER
    // fork = vm.createSelectFork(vm.rpcUrl("goerli"), BLOCK_NUMBER);

    // deploy the factory
    // HATS, SALT, instanceversion
    FACTORY = new HatsEligibilitiesChainFactory();

    // deploy via the script
    // DeployImplementation.prepare(version, false); // set last arg to true to log deployment
    // DeployImplementation.run();

    // set up hats
    tophat = HATS.mintTopHat(dao, "tophat", "dao.eth/tophat");
    vm.startPrank(dao);
    chainedEligibilityHat =
      HATS.createHat(tophat, "chainedEligibilityHat", 50, eligibility, toggle, true, "dao.eth/chainedEligibilityHat");
    vm.stopPrank();
  }
}

/**
 * Scenario with 2 modules.
 * Chaining type: module1 || module2
 * Module1 returns (true, true)
 * Module2 returns (true, true)
 * Expectesd results: (true, true)
 */
contract Setup1 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(1);
    clauseLengths.push(1);

    instance = deployInstanceTwoModules(chainedEligibilityHat, 2, clauseLengths, module1, module2);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup1 is Setup1 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(2));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }

  function test_initialized() public {
    vm.expectRevert(HatsModule.AlreadyInitialized.selector);
    instance.setUp(abi.encode("setUp attempt"));
  }
}

/**
 * Scenario with 2 modules.
 * Chaining type: module1 || module2
 * Module1 returns (false, true)
 * Module2 returns (true, true)
 * Expectesd results: (true, true)
 */
contract Setup2 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(1);
    clauseLengths.push(1);

    instance = deployInstanceTwoModules(chainedEligibilityHat, 2, clauseLengths, module1, module2);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup2 is Setup2 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(2));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 2 modules.
 * Chaining type: module1 || module2
 * Module1 returns (true, true)
 * Module2 returns (false, true)
 * Expectesd results: (true, true)
 */
contract Setup3 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(1);
    clauseLengths.push(1);

    instance = deployInstanceTwoModules(chainedEligibilityHat, 2, clauseLengths, module1, module2);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup3 is Setup3 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(2));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 2 modules.
 * Chaining type: module1 || module2
 * Module1 returns (false, true)
 * Module2 returns (false, true)
 * Expectesd results: (false, true)
 */
contract Setup4 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(1);
    clauseLengths.push(1);

    instance = deployInstanceTwoModules(chainedEligibilityHat, 2, clauseLengths, module1, module2);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup4 is Setup4 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(2));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 2 modules.
 * Chaining type: module1 && module2
 * Module1 returns (true, true)
 * Module2 returns (true, true)
 * Expectesd results: (true, true)
 */
contract Setup5 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(2);

    instance = deployInstanceTwoModules(chainedEligibilityHat, 1, clauseLengths, module1, module2);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup5 is Setup5 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(1));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 2 modules.
 * Chaining type: module1 && module2
 * Module1 returns (false, true)
 * Module2 returns (true, true)
 * Expectesd results: (false, true)
 */
contract Setup6 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(2);

    instance = deployInstanceTwoModules(chainedEligibilityHat, 1, clauseLengths, module1, module2);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup6 is Setup6 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(1));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 2 modules.
 * Chaining type: module1 && module2
 * Module1 returns (true, true)
 * Module2 returns (false, true)
 * Expectesd results: (false, true)
 */
contract Setup7 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(2);

    instance = deployInstanceTwoModules(chainedEligibilityHat, 1, clauseLengths, module1, module2);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup7 is Setup7 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(1));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 2 modules.
 * Chaining type: module1 && module2
 * Module1 returns (false, true)
 * Module2 returns (false, true)
 * Expectesd results: (false, true)
 */
contract Setup8 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(2);

    instance = deployInstanceTwoModules(chainedEligibilityHat, 1, clauseLengths, module1, module2);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup8 is Setup8 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(1));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 3 modules.
 * Chaining type: (module1 && module2) || module3
 * Module1 returns (true, true)
 * Module2 returns (true, true)
 * Module3 returns (true, true)
 * Expectesd results: (true, true)
 */
contract Setup9 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module3 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(2);
    clauseLengths.push(1);

    instance = deployInstanceThreeModules(chainedEligibilityHat, 2, clauseLengths, module1, module2, module3);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup9 is Setup9 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
    expectedModules.push(module3);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(2));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 3 modules.
 * Chaining type: (module1 && module2) || module3
 * Module1 returns (false, true)
 * Module2 returns (true, true)
 * Module3 returns (true, true)
 * Expectesd results: (true, true)
 */
contract Setup10 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module3 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(2);
    clauseLengths.push(1);

    instance = deployInstanceThreeModules(chainedEligibilityHat, 2, clauseLengths, module1, module2, module3);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup10 is Setup10 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
    expectedModules.push(module3);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(2));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 3 modules.
 * Chaining type: (module1 && module2) || module3
 * Module1 returns (true, true)
 * Module2 returns (true, true)
 * Module3 returns (false, true)
 * Expectesd results: (true, true)
 */
contract Setup11 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module3 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(2);
    clauseLengths.push(1);

    instance = deployInstanceThreeModules(chainedEligibilityHat, 2, clauseLengths, module1, module2, module3);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup11 is Setup11 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
    expectedModules.push(module3);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), version);
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(2));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, true);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 3 modules.
 * Chaining type: (module1 && module2) || module3
 * Module1 returns (false, true)
 * Module2 returns (false, true)
 * Module3 returns (false, true)
 * Expectesd results: (false, true)
 */
contract Setup12 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));
    module3 = address(new TestEligibilityAlwaysNotEligible("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(2);
    clauseLengths.push(1);

    instance = deployInstanceThreeModules(chainedEligibilityHat, 2, clauseLengths, module1, module2, module3);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup12 is Setup12 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
    expectedModules.push(module3);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), instance.version());
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(2));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, true);
  }
}

/**
 * Scenario with 3 modules.
 * Chaining type: (module1 && module2) || module3
 * Module1 returns (true, true)
 * Module2 returns (true, true)
 * Module3 returns (false, false)
 * Expectesd results: (false, false)
 */
contract Setup13 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityAlwaysEligible("test", address(HATS), chainedEligibilityHat));
    module3 = address(new TestEligibilityAlwaysBadStanding("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(2);
    clauseLengths.push(1);

    instance = deployInstanceThreeModules(chainedEligibilityHat, 2, clauseLengths, module1, module2, module3);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup13 is Setup13 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
    expectedModules.push(module3);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), instance.version());
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(2));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, false);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, false);
  }
}

/**
 * Scenario with 3 modules.
 * Chaining type: module1 && module2 && module3
 * Module1 returns (true, true)
 * Module2 returns (true, true)
 * Module3 returns (true, false)
 * Expectesd results: (false, false)
 */
contract Setup14 is DeployImplementationTest {
  function setUp() public virtual override {
    super.setUp();

    module1 = address(new TestEligibilityOnlyBadStanding("test", address(HATS), chainedEligibilityHat));
    module2 = address(new TestEligibilityOnlyBadStanding("test", address(HATS), chainedEligibilityHat));
    module3 = address(new TestEligibilityOnlyBadStanding("test", address(HATS), chainedEligibilityHat));

    clauseLengths.push(1);
    clauseLengths.push(1);
    clauseLengths.push(1);

    instance = deployInstanceThreeModules(chainedEligibilityHat, 3, clauseLengths, module1, module2, module3);

    // update hat eligibilty to the new instance
    vm.prank(dao);
    HATS.changeHatEligibility(chainedEligibilityHat, address(instance));
  }
}

contract TestSetup14 is Setup14 {
  function setUp() public virtual override {
    super.setUp();
    expectedModules.push(module1);
    expectedModules.push(module2);
    expectedModules.push(module3);
  }

  function test_deployImplementation() public {
    assertEq(instance.version_(), instance.version());
  }

  function test_instanceNumClauses() public {
    assertEq(instance.NUM_CONJUNCTION_CLAUSES(), uint256(3));
  }

  function test_instanceClauseLengths() public {
    assertEq(instance.CONJUNCTION_CLAUSE_LENGTHS(), clauseLengths);
  }

  function test_instanceModules() public {
    assertEq(instance.MODULES(), expectedModules);
  }

  function test_wearerStatusInModule() public {
    (bool eligible, bool standing) = instance.getWearerStatus(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, false);
  }

  function test_wearerStatusInHats() public {
    bool eligible = HATS.isEligible(wearer, chainedEligibilityHat);
    bool standing = HATS.isInGoodStanding(wearer, chainedEligibilityHat);
    assertEq(eligible, false);
    assertEq(standing, false);
  }
}
