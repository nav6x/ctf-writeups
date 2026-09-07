# Timekeeper's Paradox (COMPFEST 18, blockchain)

You're given a governance token, a price oracle, an upgradeable proxy, and a lending pool holding 50 ETH, and the goal is just to drain the pool. There are two decoy paths that look tempting and both fight themselves; the real bug is a storage collision between the proxy and the oracle it delegatecalls into.

My first instinct was governance: `mint` has no access control, so I could mint myself past 51% and reach quorum. But `execute` has a 7-day timelock, which is instant death on a 30-minute instance. The timelock is the bait, governance is a trap, stop looking at it.

The actual paradox is a storage layout mismatch. The proxy delegatecalls into the oracle, so oracle code runs against the proxy's storage, but slot 2 doesn't line up between them. What the oracle thinks is "latest price" the proxy thinks is "pending admin." So `getLatestPrice()` called through the proxy actually returns `pendingAdmin`, which is 0, and that zero is why every `borrow` was frozen from the very start. Once you see that, the fix is obvious: setting `pendingAdmin` *is* setting the price.

The second decoy is trying to fully take over the proxy admin, `setPendingAdmin`, then `acceptAdmin`, then `upgradeTo` an evil implementation. That path fights itself, because `acceptAdmin` zeroes `pendingAdmin`, which would wipe the exact slot I need to hold the price. You don't need admin at all.

The catch with `setPendingAdmin` is that it's callable only by the proxy on itself. But there's a `multicall`, and `multicall` makes the proxy call its own functions as itself, so the self-only check passes. So: `multicall(setPendingAdmin(address(uint160(1e18))))`. Now the pool reads the price as `1e18`. From there it's ordinary lending, `approve`, `deposit` my starter 10k TKG as collateral, and `borrowETH(50 ether)`. The pool drops to zero and `isSolved()` flips true. I didn't even need the `mint` bug in the end; the 1% starting allocation was already enough collateral once the price read as something real.

Flag: `COMPFEST18{t1m3k33p3r_pr1c3_0r4cl3_m4n1p_v14_st0r4g3_c0ll1s10n_le4k3dddddd_n0000000}`
