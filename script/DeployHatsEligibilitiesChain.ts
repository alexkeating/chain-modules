
import { config as dotEnvConfig } from "dotenv";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet, Contract } from "zksync-ethers";
import * as hre from "hardhat";

const HatsEligibilitiesChainFactory = require("../artifacts-zk/src/HatsEligibilitiesChainFactory.sol/HatsEligibilitiesChainFactory.json");

// Before executing a real deployment, be sure to set these values as appropriate for the environment being deployed
// to. The values used in the script at the time of deployment can be checked in along with the deployment artifacts
// produced by running the scripts.
const contractName = "HatsEligibilitiesChain";
const HATS_ID = 1;
const HATS = "0x32Ccb7600c10B4F7e678C7cbde199d98453D0e7e";
const SALT_NONCE = 1;
const FACTORY_ADDRESS = "0x2C8AE0B842562C8B8C35E90F51d20D39C3c018F6";
const INIT_PARAMS = "0x0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000400000000000000000000000006914631e3e71bc75a1664e3baee140cc05cae18b0000000000000000000000006b3d9bf4377ef0a0be817b9e7b8d486aee3b7876"

async function main() {
  dotEnvConfig();

  const deployerPrivateKey = process.env.PRIVATE_KEY;
  if (!deployerPrivateKey) {
    throw "Please set PRIVATE_KEY in your .env file";
  }

  console.log("Deploying " + contractName + "...");

  const zkWallet = new Wallet(deployerPrivateKey);
  const deployer = new Deployer(hre, zkWallet);
  const factory = new Contract(
    FACTORY_ADDRESS,
    HatsEligibilitiesChainFactory.abi,
    deployer.zkWallet
  );

  const tx = await factory.deployModule(
    HATS_ID,
    HATS,
    INIT_PARAMS,
    SALT_NONCE
  );
  const tr = await tx.wait();
  console.log("Hats eligibility chain deployed at " + tr.contractAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
