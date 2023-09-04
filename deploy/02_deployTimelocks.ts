import { existsSync, mkdirSync, writeFileSync } from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeploymentsExtension } from "hardhat-deploy/types";
import { config as dotenvConfig } from "dotenv";
import { getConfig } from "./config";
import { ERC20ABI, readBeneficiaries } from "./utils";

dotenvConfig();

const date = new Date();
const SAFE_PARENT_DIR = './safe';
const SAFE_FILE_SUFFIX = `transactions-${Math.floor(date.getTime() / 1000)}.json`;

const func: DeployFunction = async (
    hre: HardhatRuntimeEnvironment & { deployments: DeploymentsExtension },
): Promise<void> => {
    let deployer;
    ({ deployer } = await hre.ethers.getNamedSigners());
    if (!deployer) {
        [deployer] = await hre.ethers.getUnnamedSigners();
    }
    console.log(
        "\n============================= Deploying TimelockedDelegator Contracts ===============================",
    );

    // Get the config
    const chain = +(await hre.getChainId());
    const config = getConfig(chain);

    const submit = process.env.SUBMIT === "true";
    const fundOnDeploy = process.env.FUND_ON_DEPLOY === "true";
    console.log("deployer:", deployer.address);
    console.log("submit:", submit);
    console.log("fundOnDeploy:", fundOnDeploy);

    // Parse the csv
    const toDeploy = readBeneficiaries(config.file);

    // Create the safe dir
    const dir = `${SAFE_PARENT_DIR}/${hre.network.name}`;
    const file = `${dir}/${SAFE_FILE_SUFFIX}`;
    if (!existsSync(dir)) {
        mkdirSync(dir);
    }

    const toSubmit = [];

    // Get the factory
    const factoryDeployment = await hre.deployments.getOrNull("TimelockFactory");
    if (!factoryDeployment) {
        throw new Error(`Factory not deployed on chain ${chain}`);
    }
    const factory = (await hre.ethers.getContractAt("TimelockFactory", factoryDeployment.address)).connect(deployer);
    console.log("factory:", factoryDeployment.address);

    // Approve the factory for the sum of all funding
    const sum = toDeploy.reduce((acc, { amount }) => acc + BigInt(amount), 0n);

    const token = (await hre.ethers.getContractAt(ERC20ABI, config.timelocks[chain].token)).connect(deployer);
    const args = [deployer.address, await factory.getAddress()]
    const allowance = await token.getFunction("allowance").staticCall(...args);
    console.log("allowance:", allowance.toString());
    console.log("sum:", sum.toString());
    if (allowance < sum && fundOnDeploy) {
        // Approve the factory for the sum of all funding
        const populated = await token
            .getFunction("approve")
            .populateTransaction(factoryDeployment.address, sum - allowance);
        if (submit) {
            const tx = await deployer.sendTransaction(populated);
            console.log("submitted approve tx:", tx.hash);
            const receipt = await tx.wait();
            console.log("mined approve tx:", receipt?.hash);
        } else {
            // Write the tx to a json
            toSubmit.push({ to: populated.to, value: populated.value, data: populated.data })
        }
    }

    // Deploy the factories
    for (const { beneficiary, cliffDuration, duration, startTime, amount } of toDeploy) {
        // Get args
        const args = [
            config.timelocks[chain].token,
            beneficiary,
            config.timelocks[chain].admin,
            cliffDuration,
            startTime,
            duration,
            amount,
            fundOnDeploy ? amount : 0n,
        ]
        // Calculate
        const expected = await factory
            .getFunction("computeTimelockAddress")
            .staticCall(
                deployer.address,
                config.timelocks[chain].token,
                beneficiary,
                startTime,
                amount
            );
        if (await deployer.provider.getCode(expected) !== "0x") {
            console.log("already deployed:", expected);
            continue;
        }
        console.log("deploying timelock to:", expected)
        // Submit
        const populated = await factory
            .getFunction("deployTimelock")
            .populateTransaction(
                ...args
            );

        if (submit) {
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
            await hre.deployments.save(`Timelock-${beneficiary.toLowerCase()}-${startTime}`, {
                abi: (await hre.deployments.getArtifact("TimelockedDelegator")).abi,
                address: timelock.toLowerCase(),
                transactionHash: tx.hash,
                receipt: receipt as any,
                args: [
                    config.timelocks[chain].token,
                    beneficiary,
                    config.timelocks[chain].admin,
                    cliffDuration,
                    startTime,
                    duration,
                ]
            });
        } else {
            // Write the tx to a json
            toSubmit.push({ to: populated.to, value: populated.value, data: populated.data })
        }
    }

    // Write file
    writeFileSync(file, JSON.stringify(toSubmit, null, 2));
    // Write latest
    writeFileSync(`${dir}/transactions-latest.json`, JSON.stringify(toSubmit, null, 2));

};
func.tags = ["timelocks", "testnet", "mainnet"];
export default func;
