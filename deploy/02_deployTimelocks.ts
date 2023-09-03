import { createWriteStream } from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeploymentsExtension } from "hardhat-deploy/types";
import { Wallet } from "ethers";
import { config as dotenvConfig } from "dotenv";
import { getConfig } from "./config";
import { ERC20ABI, readBeneficiaries } from "./utils";

dotenvConfig();

const date = new Date();
const FILE = `./transactions-${date.getTime()}.json`;

const func: DeployFunction = async (
    hre: HardhatRuntimeEnvironment & { deployments: DeploymentsExtension },
): Promise<void> => {
    let _deployer;
    ({ deployer: _deployer } = await hre.getNamedAccounts());
    if (!_deployer) {
        [_deployer] = await hre.getUnnamedAccounts();
    }
    const deployer = _deployer as unknown as Wallet;
    console.log(
        "\n============================= Deploying TimelockedDelegator Contracts ===============================",
    );

    // Get the config
    const chain = +(await hre.getChainId());
    const config = getConfig(chain);

    // Parse the csv
    const toDeploy = readBeneficiaries(config.file);

    // Create the tx write stream
    const stream = createWriteStream(FILE, { flags: "a" });

    // Get the factory
    const factoryDeployment = await hre.deployments.getOrNull("TimelockFactory");
    if (!factoryDeployment) {
        throw new Error(`Factory not deployed on chain ${chain}`);
    }
    const factory = (await hre.ethers.getContractAt("TimelockFactory", factoryDeployment.address)).connect(deployer);

    // Approve the factory for the sum of all funding
    const sum = toDeploy.reduce((acc, { funding }) => acc + BigInt(funding ?? 0), 0n);

    const token = (await hre.ethers.getContractAt(ERC20ABI, config.timelocks[chain].token)).connect(deployer);
    const allowance = await token.getFunction("allowance").call(deployer.address, factoryDeployment.address);
    if (allowance < sum) {
        // Approve the factory for the sum of all funding
        const populated = await token
            .getFunction("approve")
            .populateTransaction(factoryDeployment.address, sum - allowance);

        if (process.env.SUBMIT) {
            const tx = await deployer.sendTransaction(populated);
            console.log("submitted approve tx:", tx.hash);
            const receipt = await tx.wait();
            console.log("mined approve tx:", receipt?.hash);
        } else {
            // Write the tx to a csv
            stream.write(JSON.stringify({ to: populated.to, value: populated.value, data: populated.data }) + "\n");
        }
    }

    // Deploy the factories
    for (const { beneficiary, cliffDuration, duration, startTime, funding } of toDeploy) {
        const populated = await factory
            .getFunction("deployTimelock")
            .populateTransaction(
                config.timelocks[chain].token,
                beneficiary,
                config.timelocks[chain].admin,
                cliffDuration,
                startTime,
                duration,
                funding ?? "0",
            );

        if (process.env.SUBMIT) {
            const tx = await deployer.sendTransaction(populated);
            console.log("submitted deploy tx:", tx.hash);
            const receipt = await tx.wait();
            console.log("mined deploy tx:", receipt?.hash);
            if (!receipt) {
                throw new Error(`No receipt for ${tx.hash}`);
            }

            // Save the deployment
            const parsed = receipt.logs.map((l: any) => factory.interface.parseLog(l));
            const [timelock] = parsed.find((p) => p?.name === "TimelockDeployed")?.args as any;
            await hre.deployments.save(`Timelock-${beneficiary.toLowerCase()}`, {
                abi: (await hre.deployments.getArtifact("TimelockedDelegator")).abi,
                address: timelock.toLowerCase(),
                transactionHash: tx.hash,
                receipt: receipt as any,
            });
        } else {
            // Write the tx to a csv
            stream.write(JSON.stringify({ to: populated.to, value: populated.value, data: populated.data }) + "\n");
        }
    }

    // Close the stream
    stream.close();
};
func.tags = ["timelocks", "testnet", "mainnet"];
export default func;
