"""
Cocotb testbench for tt_um_rsa_simple
RSA encryption: ciphertext = message^193 mod 4439

Pin mapping (from project.v):
  ui_in[0]      = start
  ui_in[7:1]    = message[6:0]
  uio_in[7:0]   = message[14:7]
  uo_out[7:0]   = encrypted[7:0]
  uio_out[6:0]  = encrypted[14:8]
  uio_out[7]    = done
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, with_timeout
import asyncio


def pack_message(msg: int) -> tuple[int, int]:
    """Split 15-bit message into (ui_in_bits[7:1], uio_in_bits[7:0]).
    ui_in[7:1] = message[6:0], uio_in[7:0] = message[14:7].
    Returns (ui_in_val, uio_in_val) -- ui_in bit 0 (start) NOT set here.
    """
    assert 0 <= msg < (1 << 15), "message must be 15-bit (0..32767)"
    ui_bits  = (msg & 0x7F) << 1        # message[6:0] -> ui_in[7:1]
    uio_bits = (msg >> 7) & 0xFF        # message[14:7] -> uio_in[7:0]
    return ui_bits, uio_bits


def read_result(dut) -> tuple[int, bool]:
    """Read current ciphertext and done flag from DUT outputs."""
    low  = int(dut.uo_out.value)
    high = int(dut.uio_out.value)
    done = bool((high >> 7) & 1)
    ct   = ((high & 0x7F) << 8) | low  # encrypted[14:0]
    return ct, done


def ref_rsa(message: int, e: int = 193, n: int = 4439) -> int:
    """Python reference: message^e mod n."""
    return pow(message, e, n)


async def reset_dut(dut):
    """Apply reset for a few cycles."""
    dut.rst_n.value  = 0
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


async def encrypt(dut, message: int, timeout_cycles: int = 5000) -> int:
    """Drive message + start, wait for done, return ciphertext."""
    ui_bits, uio_bits = pack_message(message)

    # Set message bits
    dut.ui_in.value  = ui_bits
    dut.uio_in.value = uio_bits
    await RisingEdge(dut.clk)

    # Pulse start for 1 cycle
    dut.ui_in.value = ui_bits | 0x01   # set start bit
    await RisingEdge(dut.clk)
    dut.ui_in.value = ui_bits           # clear start

    # Wait for done
    for _ in range(timeout_cycles):
        await RisingEdge(dut.clk)
        ct, done = read_result(dut)
        if done:
            return ct

    raise TimeoutError(f"done never asserted after {timeout_cycles} cycles for message={message}")


# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_reset(dut):
    """After reset, outputs should be 0 and done should be low."""
    clock = Clock(dut.clk, 100, units="ns")  # 10 MHz
    cocotb.start_soon(clock.start())

    await reset_dut(dut)
    _, done = read_result(dut)
    assert not done, "done should be 0 after reset"
    dut._log.info("PASS: reset test")


@cocotb.test()
async def test_encrypt_small(dut):
    """Encrypt message=2: 2^193 mod 4439, verify against Python reference."""
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    msg = 2
    expected = ref_rsa(msg)
    result   = await encrypt(dut, msg)

    dut._log.info(f"msg={msg} expected={expected} got={result}")
    assert result == expected, f"FAIL: message={msg}: expected {expected}, got {result}"
    dut._log.info("PASS: encrypt_small")


@cocotb.test()
async def test_encrypt_max(dut):
    """Encrypt message=4438 (n-1): result should be n-1 for this key."""
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    msg = 4438
    expected = ref_rsa(msg)
    result   = await encrypt(dut, msg)

    dut._log.info(f"msg={msg} expected={expected} got={result}")
    assert result == expected, f"FAIL: message={msg}: expected {expected}, got {result}"
    dut._log.info("PASS: encrypt_max")


@cocotb.test()
async def test_encrypt_zero(dut):
    """Encrypt message=0: 0^e mod n = 0."""
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    msg      = 0
    expected = ref_rsa(msg)   # 0
    result   = await encrypt(dut, msg)

    dut._log.info(f"msg={msg} expected={expected} got={result}")
    assert result == expected, f"FAIL: message={msg}: expected {expected}, got {result}"
    dut._log.info("PASS: encrypt_zero")


@cocotb.test()
async def test_encrypt_one(dut):
    """Encrypt message=1: 1^e mod n = 1."""
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    msg      = 1
    expected = ref_rsa(msg)   # 1
    result   = await encrypt(dut, msg)

    dut._log.info(f"msg={msg} expected={expected} got={result}")
    assert result == expected, f"FAIL: message={msg}: expected {expected}, got {result}"
    dut._log.info("PASS: encrypt_one")


@cocotb.test()
async def test_sequential_encryptions(dut):
    """Run two sequential encryptions without re-reset to test re-use."""
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    for msg in [7, 100]:
        expected = ref_rsa(msg)
        result   = await encrypt(dut, msg)
        dut._log.info(f"seq msg={msg} expected={expected} got={result}")
        assert result == expected, f"FAIL: seq message={msg}: expected {expected}, got {result}"
        await ClockCycles(dut.clk, 3)  # brief gap between encryptions

    dut._log.info("PASS: sequential_encryptions")
