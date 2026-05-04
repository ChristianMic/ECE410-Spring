# MaxPool2D Chiplet — Simulation README

This README documents how to compile and run the SystemVerilog testbenches for the MaxPool2D hardware accelerator chiplet, including dependencies, file descriptions, and instructions for viewing waveforms.

---

## Dependencies

| Software | Version | Purpose | Download |
|---|---|---|---|
| Icarus Verilog | 11.0+ | SystemVerilog simulator | http://bleyer.org/icarus/ |
| GTKWave | 3.3.0+ | Waveform viewer | http://gtkwave.sourceforge.net/ |

Both tools must be added to your system PATH. See the PATH setup section below if needed.

---

## File Descriptions

| File | Description |
|---|---|
| `compute_core.sv` | 2-stage comparator tree implementing MaxPool2D forward pass |
| `interface.sv` | AXI4 Stream slave/master interface wrapping the compute core |
| `tb_compute_core.sv` | Testbench for `compute_core.sv` — drives inputs directly |
| `tb_interface.sv` | Testbench for `interface.sv` — exercises AXI4 Stream protocol |

---

## Running the Compute Core Testbench

### Step 1: Compile
```bash
iverilog -g2012 -o sim_compute_core compute_core.sv tb_compute_core.sv
```

### Step 2: Run simulation
```bash
vvp sim_compute_core
```

### Step 3: Save log (optional)
```bash
vvp sim_compute_core > sim_compute_core.log
```

### Expected output
```
==============================================
 compute_core Testbench
==============================================

--- Test 1: Ascending values (max=d) ---
  Input: a=256 b=512 c=768 d=1024 (Q8.8 integers)
  PASS: max=1024 (expected 1024), mask=4'b1000 (expected 4'b1000)

--- Test 2: Descending values (max=a) ---
  ...

==============================================
 Results: 6/6 tests passed
 ALL TESTS PASSED
==============================================
```

### Test cases
| Test | Window | Expected max | Expected mask |
|---|---|---|---|
| 1 | 1, 2, 3, 4 | 4.0 (d) | `4'b1000` |
| 2 | 4, 3, 2, 1 | 4.0 (a) | `4'b0001` |
| 3 | 2, 2, 2, 2 | 2.0 (a, tie) | `4'b0001` |
| 4 | -1, -2, -3, -4 | -1.0 (a) | `4'b0001` |
| 5 | -1, 3, 1, -2 | 3.0 (b) | `4'b0010` |
| 6 | 1, 2, 5, 3 | 5.0 (c) | `4'b0100` |

---

## Running the Interface Testbench

### Step 1: Compile
Note: `compute_core.sv` must be included as `interface.sv` instantiates it internally.
```bash
iverilog -g2012 -o sim_interface compute_core.sv interface.sv tb_interface.sv
```

### Step 2: Run simulation
```bash
vvp sim_interface
```

### Step 3: Save log (optional)
```bash
vvp sim_interface > sim_interface.log
```

### Expected output
```
==============================================
 axi4_stream_interface Testbench
==============================================

--- Test 1: tready/tvalid handshaking ---
  PASS: s_axis_tready deasserted during processing and reasserted after

--- Test 2: Backpressure (m_axis_tready held low) ---
  PASS: m_axis_tvalid held high during backpressure
  ...

==============================================
 Results: 6/6 tests passed
 ALL TESTS PASSED
==============================================
```

### Test cases
| Test | What is verified |
|---|---|
| 1 | `s_axis_tready` deasserts during processing and reasserts after |
| 2 | `m_axis_tvalid` stays high when `m_axis_tready` is held low (backpressure) |
| 3 | `m_axis_tlast` asserts with `tvalid` and deasserts after acceptance |
| 4 | Two consecutive windows produce correct independent results |
| 5 | Outputs clear correctly when reset is asserted mid-transaction |
| 6 | Interface recovers and completes a normal transaction after reset |

---

## Viewing Waveforms in GTKWave

Both testbenches automatically generate VCD waveform files when simulated.

### Step 1: Run the simulation (generates VCD file)
```bash
vvp sim_compute_core    # generates tb_compute_core.vcd
vvp sim_interface       # generates tb_interface.vcd
```

### Step 2: Open GTKWave
```bash
gtkwave tb_compute_core.vcd
# or
gtkwave tb_interface.vcd
```

### Step 3: Add signals
1. In the left panel click on the module name (e.g. `tb_compute_core`)
2. Signals appear in the panel below
3. Select signals of interest and click **Append**

### Recommended signals for compute core
- `clk`, `rst_n`, `valid_in`
- `a`, `b`, `c`, `d`
- `max_out`, `mask_out`, `valid_out`

### Recommended signals for interface
- `clk`, `rst_n`
- `s_axis_tdata`, `s_axis_tvalid`, `s_axis_tready`, `s_axis_tlast`
- `m_axis_tdata`, `m_axis_tvalid`, `m_axis_tready`, `m_axis_tlast`

### Useful GTKWave shortcuts
| Shortcut | Action |
|---|---|
| `Ctrl + Shift + F` | Fit waveform to window |
| `Scroll wheel` | Zoom in/out |
| `Middle click drag` | Zoom to region |
| Right click signal → Data Format | Change display format (hex, decimal, binary) |

---

## PATH Setup (if needed)

If `iverilog` or `gtkwave` are not recognised as commands:

1. Press **Win + R**, type `sysdm.cpl`, hit Enter
2. Go to **Advanced → Environment Variables**
3. Under **System variables**, select **Path → Edit → New**
4. Add the path to your install bin folder, typically:
   ```
   C:\iverilog\bin
   ```
5. Click OK on all windows
6. **Close and reopen your terminal** for the change to take effect

Verify with:
```bash
iverilog -v
gtkwave --version
```

---

## Notes

- All values are encoded in **Q8.8 fixed-point** format. To convert a real number multiply by 256 (e.g. 1.0 = 256, 2.0 = 512).
- The compute core has a **2 cycle pipeline latency** from `valid_in` to `valid_out`.
- The interface has a **4 cycle total latency** from the first input word to `m_axis_tvalid`.
- The `-g2012` flag is required for SystemVerilog support in Icarus Verilog.
