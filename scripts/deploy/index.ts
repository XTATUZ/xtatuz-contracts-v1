/* eslint-disable camelcase */
import { BigNumberish } from "ethers";
import { parseEther } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";

import * as typechain from "../../typechain";
import { savaAddress } from "./../../utils/address";

export const deployToken = async (name: string, symbol: string) => {
  const Contract = (await ethers.getContractFactory("Token")) as typechain.Token__factory;
  const contract = await Contract.deploy(name, symbol);

  await savaAddress(hre.network.name, {
    [symbol]: contract.address,
  });

  return contract;
};

export const deployXTAToken = async (name: string, symbol: string, totalSupply: string) => {
  const Contract = (await ethers.getContractFactory("XTAToken")) as typechain.XTAToken__factory;
  const contract = await Contract.deploy(name, symbol, parseEther(totalSupply));

  await savaAddress(hre.network.name, {
    [symbol]: contract.address,
  });

  return contract;
};

export const deployPresaledFactory = async () => {
  const Contract = (await ethers.getContractFactory("PresaledFactory")) as typechain.PresaledFactory__factory;
  const contract = await Contract.deploy();

  await savaAddress(hre.network.name, {
    PresaledFactory: contract.address,
  });

  return contract;
}

export const deployPropertyFactory = async () => {
  const Contract = (await ethers.getContractFactory("PropertyFactory")) as typechain.PropertyFactory__factory;
  const contract = await Contract.deploy();

  await savaAddress(hre.network.name, {
    PropertyFactory: contract.address,
  });

  return contract;
}

export const deployProjectFactory = async () => {
 const Contract = (await ethers.getContractFactory("ProjectFactory")) as typechain.ProjectFactory__factory;
 const contract = await Contract.deploy();

 await savaAddress(hre.network.name, {
  ProjectFactory: contract.address,
});

return contract;
}

export const deployXtatuzFactory = async (propertyFactory: string, presaledFactory: string, projectFactory: string) => {
  const Contract = (await ethers.getContractFactory("XtatuzFactory")) as typechain.XtatuzFactory__factory;
  const contract = await Contract.deploy(propertyFactory, presaledFactory, projectFactory);

  await savaAddress(hre.network.name, {
    XtatuzFactory: contract.address,
  });

  return contract;
}

export const deployRouter = async (spv: string, factoryAddress: string) => {
  const Contract = (await ethers.getContractFactory("XtatuzRouter")) as typechain.XtatuzRouter__factory;
  const contract = await Contract.deploy(spv, factoryAddress);

  await savaAddress(hre.network.name, {
    XtatuzRouter: contract.address,
  });

  return contract;
}

export const deployReferral = async (tokenAddress: string, initialPercentage: Array<BigNumberish>) => {
  const Contract = (await ethers.getContractFactory("XtatuzReferral")) as typechain.XtatuzReferral__factory;
  const contract = await Contract.deploy(tokenAddress, initialPercentage);

  await savaAddress(hre.network.name, {
    XtatuzReferral: contract.address,
  });

  return contract;
}

export const deployReroll = async (spv: string, xtaAddress: string, routerAddress: string, tokenAddress: string) => {
  const Contract = (await ethers.getContractFactory("XtatuzReroll")) as typechain.XtatuzReroll__factory;
  const contract = await Contract.deploy(spv, routerAddress, tokenAddress);

  await savaAddress(hre.network.name, {
    XtatuzReroll: contract.address,
  });

  return contract;
}