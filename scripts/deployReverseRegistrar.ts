const { ethers } = require('hardhat');

async function main() {
  // RPC URL (the same one you used for deployment)
  const rpcUrl = 'https://rpc.testnet.lukso.network';

  // Contract address (replace with your contract's deployed address)
  const contractAddress = '0x648497a80c0499BEb5e18965Ba45c9A8B809EB4e';

  // Connect to the RPC endpoint
  const provider = new ethers.JsonRpcProvider(rpcUrl);

  // Get the signer (the same way as in your deployment script)
  const [deployer] = await ethers.getSigners();

  // eth controller
  // const myReverseRegistrar = await ReverseRegistrar.connect(deployer).deploy(
  //   '0x5c329bDC814bdD43AEDBaeF9CceF6E8BdB557Bff',
  //   '0xCC4AA3F0f1F4a0b49b82130b801DBcBc3EC456A6',
  //   '0xc60BCe293c948fc0C6E5235A9b23c4b9145eA481',
  //   60,
  //   1000,
  // );

  // Deploy MyContract
  const ReverseRegistrar = await ethers.getContractFactory('ReverseRegistrar');
  const myReverseRegistrar = await ReverseRegistrar.connect(deployer).deploy(
    '0x648497a80c0499BEb5e18965Ba45c9A8B809EB4e',
  );

  console.log('MyContract deployed to:', myReverseRegistrar.target);

  // Get the contract ABI
  const MyContract = await ethers.getContractFactory('UNSRegistry');

  // Get the contract instance
  const myContract = new ethers.Contract(contractAddress, MyContract.interface, deployer);

  // await myContract.addController(myReverseRegistrar.target);

  // Prepare the arguments
  const parentNameHash = ethers.ZeroHash; // bytes32(0)

  // //   Call the setSubNameRecord function
  const newtx = await myContract
    .connect(deployer)
    .setSubNameRecord(
      parentNameHash,
      ethers.keccak256(ethers.toUtf8Bytes('reverse')),
      deployer.address,
      ethers.ZeroAddress,
      0,
    );

  // // Wait for the transaction to be mined
  await newtx.wait();

  const rdtx = await myContract
    .connect(deployer)
    .setSubNameRecord(
      '0xa097f6721ce401e757d1223a763fef49b8b5f90bb18567ddb86fd205dff71d34',
      ethers.keccak256(ethers.toUtf8Bytes('addr')),
      myReverseRegistrar.target,
      ethers.ZeroAddress,
      0,
    );

  // // Wait for the transaction to be mined
  await rdtx.wait();

  console.log('SubNameRecord set successfully');

  // Now you can interact with the contract
  // For example, call a function of your contract
  // const result = await myContract.yourFunctionName(arg1, arg2, ...);

  // Example: Assuming 'yourFunctionName' is a function in your contract
  // console.log(`Function call result: ${result}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
