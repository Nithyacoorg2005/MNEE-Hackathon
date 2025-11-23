const { ethers } = require("hardhat");

async function main() {
  console.log("--- Deployment Started ---");

  // 1. Deploy the Mock MNEE ERC20 Token (MNEE_ADDRESS)
  // NOTE: Ensure your contracts/ folder contains MNEE_Mock_Token.sol
  const MNEEFactory = await ethers.getContractFactory("MNEE_Mock_Token"); 
  const MNEE_Contract = await MNEEFactory.deploy();
  await MNEE_Contract.deployed();
  console.log(`MNEE Mock Token deployed to: ${MNEE_Contract.address}`);
  
  // 2. Deploy the RetentionRelay Contract (RELAY_ADDRESS)
  // NOTE: RetentionRelay requires the MNEE token address in its constructor.
  const RelayFactory = await ethers.getContractFactory("RetentionRelay");
  const RELAY_Contract = await RelayFactory.deploy(MNEE_Contract.address); 
  await RELAY_Contract.deployed();
  console.log(`RetentionRelay deployed to: ${RELAY_Contract.address}`);

  // --- CRITICAL DATA OUTPUT ---
  console.log("\n--- COPY THESE ADDRESSES TO index.html ---");
  console.log(`MNEE_ADDRESS = "${MNEE_Contract.address}"`);
  console.log(`RELAY_ADDRESS = "${RELAY_Contract.address}"`);
  // REMEMBER TO USE YOUR SECOND METAMASK ADDRESS FOR THE MERCHANT
  console.log(`MERCHANT_ADDRESS = "YOUR_SECOND_METAMASK_ADDRESS_HERE"`); 
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});