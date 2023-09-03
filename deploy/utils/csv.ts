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
  const lines = contents.split("\n").filter(x => !!x);
  const headerLine = lines.shift() as string;
  const keys = headerLine.split(",").map(x => x.startsWith('"') ? x.substring(1, x.length - 1) : x);
  const ret = lines.map((line) => {
    const entry = {} as any;
    const values = line.split(",").map(x => typeof x === "string" && x.startsWith('"') ? x.substring(1, x.length - 1) : x);
    keys.forEach((key, i) => {
      entry[key] = values[i];
    });
    return entry;
  });
  return ret;
};
