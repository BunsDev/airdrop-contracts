import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { exec as _exec } from "child_process";
import util from "util";

const exec = util.promisify(_exec);

/**
 * Hardhat task defining the contract deployments for Connext
 *
 * @param hre Hardhat environment to deploy to
 */
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment): Promise<void> => {
  console.log("\n============================= Exporting + Verifying Deployments ===============================");
  await hre.run("export", {
    exportAll: "./deployments.json",
  });

  // This should veirfy the timelock factory
  await hre.run("etherscan-verify", {
    solcInput: true,
  });

  // Get all the timelock deployments
  const deployments = await hre.deployments.all();

  const chain = await hre.getChainId();

  const factoryDeployment = await hre.deployments.getOrNull("TimelockFactory");
  if (!factoryDeployment) {
    console.log("No factory deployment found, skipping timelock verification");
    return;
  }

  for (const [name, deployment] of Object.entries(deployments)) {
    if (!name.includes("Timelock-")) {
      console.log(`Skipping ${name} because it has no deployment`);
      continue;
    }

    if (!deployment) {
      console.log(`Skipping ${name} because it has no deployment`);
      continue;
    }

    if (!deployment.args) {
      console.log(`Skipping ${name} because it has no args`);
      continue
    }

    console.log("verifying", name, "@", deployment.address)

    // construct arg
    const [token, beneficiary, admin, cliff, startTime, duration] = deployment.args
    const { stdout, stderr } = await exec(`forge verify-contract --chain-id ${chain} --constructor-args $(cast abi-encode "constructor(address,address,address,uint256,uint256,uint256)" "${token}" "${beneficiary}" "${admin}" ${cliff} ${startTime} ${duration}) "${deployment.address}" "src/timelocks/TimelockedDelegator.sol:TimelockedDelegator"`)
    if (stderr) {
      throw new Error(stderr)
    }
    console.log(stdout)
  }
};

export default func;
func.tags = ["export", "testnet"];
