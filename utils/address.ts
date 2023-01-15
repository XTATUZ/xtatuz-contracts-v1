/* eslint-disable node/no-path-concat */
import * as fs from "fs";
import { promisify } from "util";

const getAddressPath = (network: string) => `${__dirname}/../address/${network}.json`;

const getAddressList = async (network: string): Promise<Record<string, string>> => {
  const addressPath = getAddressPath(network);
  try {
    const data = await promisify(fs.readFile)(addressPath);
    return JSON.parse(data.toString());
  } catch (e) {
    return {};
  }
};

export const savaAddress = async (network: string, newList: Record<string, string>) => {
  const path = getAddressPath(network);
  const list = await getAddressList(network);

  const pathArr = path.split("/");
  const dirPath = [...pathArr].slice(0, pathArr.length - 1).join("/");

  if (!fs.existsSync(dirPath)) fs.mkdirSync(dirPath);

  return fs.writeFileSync(
    path,
    JSON.stringify({
      ...list,
      ...newList,
    })
  );
};

export default {
  getAddressPath,
  getAddressList,
  savaAddress,
};
