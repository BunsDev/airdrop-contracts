import { MAINNET_CONFIG } from "./mainnet";
import { TESTNET_CONFIG } from "./testnet";

export * from "./mainnet";
export * from "./testnet";

export const getConfig = (chainId: number): DeployConfig => {
    const mainnet = Object.keys(MAINNET_CONFIG.timelocks);
    const testnet = Object.keys(TESTNET_CONFIG.file);
    if (mainnet.includes(chainId.toString())) {
        return MAINNET_CONFIG;
    }
    if (testnet.includes(chainId.toString())) {
        return TESTNET_CONFIG;
    }
    throw new Error(`Unsupported chainId: ${chainId}`);
};

export type DeployConfig = {
    file: string;
    timelocks: Record<
        number,
        {
            admin: string;
            token: string;
        }
    >;
};
