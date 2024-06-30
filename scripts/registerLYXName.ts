const { ethers } = require('hardhat');

async function main() {
  // RPC URL (the same one you used for deployment)
  const rpcUrl = 'https://rpc.testnet.lukso.network';

  // Contract address (replace with your contract's deployed address)
  const contractAddress = '0x5c329bDC814bdD43AEDBaeF9CceF6E8BdB557Bff';

  // Connect to the RPC endpoint
  const provider = new ethers.JsonRpcProvider(rpcUrl);

  // Get the signer (the same way as in your deployment script)
  const [deployer] = await ethers.getSigners();

  // Get the contract ABI
  const MyContract = await ethers.getContractFactory('LYXRegistrar');

  // Get the contract instance
  const myContract = new ethers.Contract(contractAddress, MyContract.interface, provider);

  const PublicResolver = await ethers.getContractFactory('PublicResolver');
  const publicResolver = PublicResolver.interface;

  const node1 = '0x61c9ce4215afaaaa2285f23185063eacc28da12937b0e47617658eb01393c2fc';
  const addr1 = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';
  const encodedData1 = publicResolver.encodeFunctionData('setAddr(bytes32,address)', [
    node1,
    addr1,
  ]);
  console.log('Encoded setAddr(bytes32, address):', encodedData1);

  // Encode setContenthash(bytes32 node, bytes calldata hash)
  const node3 = '0x61c9ce4215afaaaa2285f23185063eacc28da12937b0e47617658eb01393c2fc';
  const contentHash =
    '0xe5010172002408011220066e20f72cc583d769bc8df5fedff24942b3b8941e827f023d306bdc7aecf5ac';
  const encodedData3 = publicResolver.encodeFunctionData('setContenthash', [node3, contentHash]);
  console.log('Encoded setContenthash(bytes32, bytes):', encodedData3);

  //   Call the setSubNameRecord function
  const tx = await myContract
    .connect(deployer)
    .register(
      ethers.keccak256(ethers.toUtf8Bytes('yamen')),
      deployer.address,
      '0x',
      '0x986e7a271Ba83D49f22ec5642138b57682e5e2c4',
      [],
      3600000,
    );

  // Wait for the transaction to be mined
  await tx.wait();

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
