import path from "path";

import {
  emulator,
  init,
  getAccountAddress,
  shallPass,
  shallResolve,
  shallRevert,
  mintFlow,
} from "@onflow/flow-js-testing";

import {
  toUFix64,
  getFirstDex,
  getSecondDex,
  getFlashLoanProvider,
  getTokensDeployer,
  getFlashLoanUser,
  getAlice,
  getBob,
  getCharlie,
} from "./src/common";

import {
  deployBasicToken1,
  deployBasicToken2,
  deploySwapConfig,
  deploySwapError,
  deploySwapInterfaces,
  deploySwapFactory,
  deploySwapRouter,
  deploySwapPair,
  deployArbitrage,
  setupBasicToken1,
  setupBasicToken2,
  getPairAddress,
  createPair,
  addLiquidity,
  getFlashLoan,
  removeLiquidity,
  transferToken1,
  transferToken2,
  getContracts,
} from "./main";

let token0Key;
let token1Key;

describe("Arbitrage", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../");
    const emulatorOptions = {
      logging: true,
    };

    await init(basePath);
    await emulator.start(emulatorOptions);

    const DEX1 = await getFirstDex();
    const Alice = await getAlice();
    // const Bob = await getBob();
    // const Charlie = await getCharlie();
    const FlashLoanUser = await getFlashLoanUser();

    await mintFlow(DEX1, "10.0");
    await mintFlow(Alice, "10.0");
    await mintFlow(FlashLoanUser, "10.0");
    await deployBasicToken1();
    await deployBasicToken2();

    await deploySwapConfig(DEX1);
    await deploySwapError(DEX1);

    await deploySwapInterfaces(DEX1);
    await deploySwapFactory(DEX1);
    await deploySwapPair(DEX1);
    await setupBasicToken1(Alice);
    await setupBasicToken2(Alice);
    await setupBasicToken1(FlashLoanUser);
    await setupBasicToken2(FlashLoanUser);

    // setting up liquidity for DEXes
    const amountToken0 = 1000_000;
    const amountToken0Min = 999_999;
    const amountToken1 = 1000_000;
    const amountToken1Min = 999_999;
    await transferToken1(amountToken0*10, Alice);
    await transferToken2(amountToken1*10, Alice);

    // Alice provides 1M/1M on DEX1
    let [txResult1] = await createPair(Alice, DEX1);
    let data1 = txResult1.events[10].data;
    await addLiquidity(
      data1.token0Key,
      data1.token1Key,
      amountToken0,
      amountToken0Min,
      amountToken1,
      amountToken1Min,
      Alice,
      DEX1
    );
    console.log("-----Created pair --------: ", data1);
    token0Key = data1.token0Key;
    token1Key = data1.token1Key;

    // setup basic tokens for flashLoanUser
    await deployArbitrage();
  });

  afterEach(async () => {
    await emulator.stop();
  });

  it("user can borrow a flashloan and perform an arbitrage", async () => {
    const flashLoanUser = await getFlashLoanUser();
    const flashLoanProvider = await getFirstDex();

    console.log("---Starting Flash Loan transaction-----")
    let [result] = await
      getFlashLoan(
        token0Key,
        token1Key,
        token0Key,
        flashLoanUser,
        500,
        flashLoanProvider
      );
      console.log("----Events from Flash loan transaction ------")
      console.log(result.events)
    // await shallPass(startArbitrage());
  });
});
