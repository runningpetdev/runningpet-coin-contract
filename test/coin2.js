"use strict"

var RunningPetCoin = artifacts.require("./RunningPetCoin.sol");
const theBN = require("bn.js")

/**
 * RunningPetCoin contract tests 2
 */
contract('RunningPetCoin2', function(accounts) {
  const BIG = (v) => new theBN.BN(v)

  const owner = accounts[0];
  const admin = accounts[1];
  const vault = accounts[2];
  const minter = accounts[0];

  const user1 = accounts[4];
  const user2 = accounts[5];
  const user3 = accounts[6];
  const user4 = accounts[7];
  const user5 = accounts[8];

  let coin, OneRunningPetCoinInMinunit, NoOfTokens, NoOfTokensInMinunit;

  const bnBalanceOf = async addr => await coin.balanceOf(addr);
  const bnReserveOf = async addr => await coin.reserveOf(addr);
  const bnAllowanceOf = async (owner, spender) => await coin.allowance(owner, spender);

  const balanceOf = async addr => (await coin.balanceOf(addr)).toString();
  const reserveOf = async addr => (await coin.reserveOf(addr)).toString();
  const allowanceOf = async (owner, spender) => (await coin.allowance(owner,spender)).toString();


  before(async () => {
    coin = await RunningPetCoin.deployed();
    NoOfTokensInMinunit = await coin.totalSupply();
    OneRunningPetCoinInMinunit = await coin.getOneRunningPetCoin();
    NoOfTokens = NoOfTokensInMinunit.div(OneRunningPetCoinInMinunit)
  });

  const clearUser = async user => {
    await coin.setReserve(user, 0, {from: admin});
    await coin.transfer(vault, await bnBalanceOf(user), {from: user});
  };

  beforeEach(async () => {
    await clearUser(user1);
    await clearUser(user2);
    await clearUser(user3);
    await clearUser(user4);
    await clearUser(user5);
  });

  it("reserve and then approve", async() => {
    assert.equal(await balanceOf(user4), "0");

    const OneRunningPetTimesTwoInMinunit = OneRunningPetCoinInMinunit.mul(BIG(2))
    const OneRunningPetTimesTwoInMinunitStr = OneRunningPetTimesTwoInMinunit.toString()

    const OneRunningPetTimesOneInMinunit = OneRunningPetCoinInMinunit.mul(BIG(1))
    const OneRunningPetTimesOneInMinunitStr = OneRunningPetTimesOneInMinunit.toString()

    // send 2 RunningPet to user4 and set 1 RunningPet reserve
    coin.transfer(user4, OneRunningPetTimesTwoInMinunit, {from: vault});
    coin.setReserve(user4, OneRunningPetCoinInMinunit, {from: admin});
    assert.equal(await balanceOf(user4), OneRunningPetTimesTwoInMinunitStr);
    assert.equal(await reserveOf(user4), OneRunningPetCoinInMinunit.toString());

    // approve 2 RunningPet to user5
    await coin.approve(user5, OneRunningPetTimesTwoInMinunit, {from:user4});
    assert.equal(await allowanceOf(user4, user5), OneRunningPetTimesTwoInMinunitStr);

    // transfer 2 RunningPet from user4 to user5 SHOULD NOT BE POSSIBLE
    try {
      await coin.transferFrom(user4, user5, OneRunningPetTimesTwoInMinunit, {from: user5});
      assert.fail();
    } catch(exception) {
      assert.isTrue(exception.message.includes("revert"));
    }

    // transfer 1 RunningPet from user4 to user5 SHOULD BE POSSIBLE
    await coin.transferFrom(user4, user5, OneRunningPetTimesOneInMinunit, {from: user5});
    assert.equal(await balanceOf(user4), OneRunningPetTimesOneInMinunitStr);
    assert.equal(await reserveOf(user4), OneRunningPetTimesOneInMinunitStr); // reserve will not change
    assert.equal(await allowanceOf(user4, user5), OneRunningPetTimesOneInMinunitStr); // allowance will be reduced
    assert.equal(await balanceOf(user5), OneRunningPetTimesOneInMinunitStr);
    assert.equal(await reserveOf(user5), "0");

    // transfer .5 RunningPet from user4 to user5 SHOULD NOT BE POSSIBLE if balance <= reserve
    const halfRunningPetInMinunit = OneRunningPetCoinInMinunit.div(BIG(2));
    try {
      await coin.transferFrom(user4, user5, halfRunningPetInMinunit, {from: user5});
      assert.fail();
    } catch(exception) {
      assert.isTrue(exception.message.includes("revert"));
    }
  })

  it("only minter can call mint", async() => {
      const OneRunningPetTimesTenInMinunit = OneRunningPetCoinInMinunit.mul(BIG(10))
      const OneRunningPetTimesTenInMinunitStr = OneRunningPetTimesTenInMinunit.toString()

      assert.equal(await balanceOf(user4), "0");

      await coin.mint(user4, OneRunningPetTimesTenInMinunit, {from: minter})

      const totalSupplyAfterMintStr = (await coin.totalSupply()).toString()
      assert.equal(totalSupplyAfterMintStr, OneRunningPetTimesTenInMinunit.add(NoOfTokensInMinunit).toString())
      assert.equal(await balanceOf(user4), OneRunningPetTimesTenInMinunitStr);

      try {
          await coin.mint(user4, OneRunningPetTimesTenInMinunit, {from: user4})
          assert.fail();
      } catch(exception) {
          assert.equal(totalSupplyAfterMintStr, OneRunningPetTimesTenInMinunit.add(NoOfTokensInMinunit).toString())
          assert.isTrue(exception.message.includes("revert"));
      }
  })

  it("cannot mint above the mint cap", async() => {
      const OneRunningPetTimes100BilInMinunit = 
              OneRunningPetCoinInMinunit.mul(BIG(100000000000))

      assert.equal(await balanceOf(user4), "0");


      try {
          await coin.mint(user4, OneRunningPetTimes100BilInMinunit, {from: minter})
          assert.fail();
      } catch(exception) {
          assert.isTrue(exception.message.includes("revert"));
      }
  })
});
