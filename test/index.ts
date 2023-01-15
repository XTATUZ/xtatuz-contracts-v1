import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";

describe("Xtatuz Contract", function () {
  async function deployRouter() {
    const [owner, otherAccount] = await ethers.getSigners();
    const FakeXta = await ethers.getContractFactory("XTAToken");
    const fakeXta = await FakeXta.deploy("XTA Token", "XTA", parseEther("1500000000"));

    return { fakeXta, owner, otherAccount };
  }
});
