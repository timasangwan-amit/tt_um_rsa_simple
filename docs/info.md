# RSA Simple Encryptor

## How it works

This project implements textbook RSA encryption in hardware. It computes:

```
ciphertext = message^e mod n
```

with hardcoded public key **e = 193**, **n = 4439**.

The core algorithm is **square-and-multiply modular exponentiation** (`modexp.v`).
To fit within a TinyTapeout 1x1 tile, the internal multiplier uses a **shift-and-add**
approach (`modmul` submodule) that takes 32 clock cycles per multiply instead of
synthesizing a full 32x32 combinational multiplier. Each encryption of a 15-bit
message takes approximately **32 x 32 x 16 ~ 16,000 clock cycles** worst-case
(one multiply per bit of exponent x 16 bits in exponent x 32 cycles/multiply).

> This is a **textbook** RSA implementation for educational/demonstration use
> only. The key size (13-bit n) is trivially breakable and offers no real security.

---

## Pinout

| Pin | Direction | Description |
|-----|-----------|-------------|
| `ui[0]` | Input | **start** - pulse high for 1 clock cycle to begin encryption |
| `ui[7:1]` | Input | `message[6:0]` - low 7 bits of 15-bit plaintext |
| `uio[7:0]` | Input (during load) | `message[14:7]` - upper 8 bits of 15-bit plaintext |
| `uo[7:0]` | Output | `encrypted[7:0]` - low byte of ciphertext (valid when done=1) |
| `uio[6:0]` | Output (after done) | `encrypted[14:8]` - bits [14:8] of ciphertext |
| `uio[7]` | Output | **done** - pulses high for 1 cycle when ciphertext is ready |

> Note: `uio` pins are always outputs (`uio_oe = 0xFF`). The message[14:7] bits
> are sampled from `uio_in` on the clock edge when `start` is pulsed.

---

## Usage

1. Set `ui[7:1]` and `uio_in[7:0]` to carry the 15-bit plaintext message.
2. Pulse `ui[0]` (start) high for exactly **1 clock cycle**.
3. Keep `ui[7:1]` / `uio_in[7:0]` stable until `done` goes high.
4. When `uio_out[7]` (done) pulses high, read the ciphertext:
   - `uo_out[7:0]`  -> `encrypted[7:0]`
   - `uio_out[6:0]` -> `encrypted[14:8]`

### Example (Python / cocotb)

```python
# message = 42
ui_in  = (42 & 0x7F) << 1    # message[6:0] in ui_in[7:1]
uio_in = (42 >> 7) & 0xFF    # message[14:7] in uio_in[7:0]

# Pulse start
dut.ui_in.value  = ui_in | 0x01
await ClockCycles(dut.clk, 1)
dut.ui_in.value  = ui_in        # clear start

# Wait for done
while not (int(dut.uio_out.value) >> 7):
    await RisingEdge(dut.clk)

# Read result
ct = ((int(dut.uio_out.value) & 0x7F) << 8) | int(dut.uo_out.value)
# Verify: pow(42, 193, 4439) == ct
```

---

## Clock

Designed and verified at **10 MHz**. Higher frequencies may work but have not
been characterized. The only combinational paths are adders and comparators
(no multipliers), so timing should be comfortable.

---

## Resource estimate

| Resource | Estimate |
|----------|----------|
| Tile size | 1x1 |
| Key registers | ~160 flip-flops |
| Critical path | 32-bit adder + comparator (~8 gate delays) |
| Cycles per encryption | ~16,000 worst case at 193 exponent bits |
| Time per encryption @ 10 MHz | ~1.6 ms |
