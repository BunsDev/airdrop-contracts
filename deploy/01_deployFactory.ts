import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeploymentsExtension } from "hardhat-deploy/types";
import { Wallet } from "ethers";
import { config as dotenvConfig } from "dotenv";

dotenvConfig();

const func: DeployFunction = async (
    hre: HardhatRuntimeEnvironment & { deployments: DeploymentsExtension },
): Promise<void> => {
    let _deployer;
    ({ deployer: _deployer } = await hre.ethers.getNamedSigners());
    if (!_deployer) {
        [_deployer] = await hre.ethers.getUnnamedSigners();
    }
    const deployer = _deployer as unknown as Wallet;
    console.log("\n============================= Deploying TimelockFactory Contract ===============================");

    // Deploy create3 factory
    console.log("deploying factory..");
    const { address, deploy } = await hre.deployments.deterministic("TimelockFactory", {
        from: deployer.address,
        log: true,
        skipIfAlreadyDeployed: true,
        salt: process.env.SALT,
    });

    const factoryDeployment = await deploy();
    if (address !== factoryDeployment.address) {
        throw new Error(`Factory address mismatch: ${address} != ${factoryDeployment.address}`);
    }
    console.log("factory deployed:", factoryDeployment.address);
};
func.tags = ["factory", "testnet", "mainnet"];
export default func;
