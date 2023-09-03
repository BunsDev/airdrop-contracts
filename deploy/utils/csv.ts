import { readFileSync } from "fs";

export type TimelockFileConfig = {
    beneficiary: string;
    cliffDuration: string;
    startTime: string;
    duration: string;
    funding?: string;
};

export const readBeneficiaries = (file: string): TimelockFileConfig[] => {
    return readCsvSync<TimelockFileConfig>(file);
};

const readCsvSync = <T extends object>(file: string): T[] => {
    const contents = readFileSync(file, "utf8");
    const lines = contents.split("\n");
    const [headerLine, ...records] = lines;
    const keys = headerLine.split(",");
    const ret = records.map((line, idx) => {
        const entry = {} as any;
        const values = line.split(",");
        keys.forEach((key, i) => {
            entry[key] = values[i];
        });
        return entry;
    });
    return ret;
};
