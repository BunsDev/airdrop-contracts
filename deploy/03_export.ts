import { readFileSync } from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { exec as _exec } from "child_process";
import util from "util";
import { ethers } from "ethers";
import axios from "axios";

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
      continue;
    }

    console.log("verifying", name, "@", deployment.address);

    // construct arg
    const [token, beneficiary, admin, cliff, startTime, duration] = deployment.args;
    // await hre.run("verify:verify", {
    //   address: deployment.address,
    //   contract: "src/timelocks/TimelockedDelegator.sol:TimelockedDelegator",
    //   constructorArguments: [token, beneficiary, admin, cliff, startTime, duration],
    // });

    const apiUrl = +chain === 1 ? "https://api.etherscan.io/api" : "https://api-goerli.etherscan.io/api";
    const response = await axios.post(
      apiUrl,
      {
        apikey: process.env.ETHERSCAN_API_KEY!, //A valid API-Key is required
        module: "contract", //Do not change
        action: "verifysourcecode", //Do not change
        contractaddress: deployment.address, //Contract Address starts with 0x...
        sourceCode: readFileSync("./TimelockedDelegator.sol", "utf8"), //Contract Source Code (Flattened if necessary)
        codeformat: "solidity-single-file", //solidity-single-file (default) or solidity-standard-json-input (for std-input-json-format support
        contractname: "TimelockedDelegator", //ContractName (if codeformat=solidity-standard-json-input, then enter contractname as ex: erc20.sol:erc20)
        compilerversion: "v0.8.19+commit.7dd6d404", // see https://etherscan.io/solcversions for list of support versions
        optimizationUsed: 1, //0 = No Optimization, 1 = Optimization used (applicable when codeformat=solidity-single-file)
        runs: 200, //set to 200 as default unless otherwise  (applicable when codeformat=solidity-single-file)
        constructorArguements: ethers.AbiCoder.defaultAbiCoder()
          .encode(
            ["address", "address", "address", "uint256", "uint256", "uint256"],
            [token, beneficiary, admin, cliff, startTime, duration],
          )
          .slice(2), //if applicable
        licenseType: 3,
      },
      {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
      },
    );

    await new Promise((r) => setTimeout(r, 5000));
    if (response.data.status === "1") {
      console.log(
        (
          await axios.get(apiUrl, {
            params: {
              apikey: process.env.ETHERSCAN_API_KEY!, //A valid API-Key is required
              guid: response.data.result,
              module: "contract", //Do not change
              action: "checkverifystatus", //Do not change
            },
          })
        ).data,
      );
    } else {
      console.log(response.data.result);
    }

    // const { stdout, stderr } = await exec(
    //   `forge verify-contract --chain-id ${chain} --watch  --constructor-args $(cast abi-encode "constructor(address,address,address,uint256,uint256,uint256)" "${token}" "${beneficiary}" "${admin}" ${cliff} ${startTime} ${duration}) "${deployment.address}" "src/timelocks/TimelockedDelegator.sol:TimelockedDelegator"`,
    // );
    // if (stderr) {
    //   throw new Error(stderr);
    // }
    // console.log(stdout);
  }
};

export default func;
func.tags = ["export", "testnet"];
