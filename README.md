# Systolic Array Matrix Multiplier Design Project

# Phase 1: Single Processing Element (PE) - COMPLETE
 
Foundation module for the systolic array matrix multiplier project. This PE
is the atomic building block: in Phase 2, a grid of these gets wired
together to form the array.
 
## What it does
 
Weight-stationary MAC unit:
- `weight_in` is loaded once (held in `weight_reg`, gated by `load_weight`)
  and reused across many multiply-accumulates - this is the
  "weight-stationary" dataflow choice.
- `act_in` streams in every cycle (will come from the PE to the left, or
  from the array's input edge, in Phase 2).
- `psum_in` streams in every cycle (will come from the PE above, or `0` for
  the top row).
- Each cycle computes `psum_out = psum_in + (weight * act_in)`, and passes
  `act_in` along to `act_out` so the next PE in the row can use it.
## Pipeline structure (2 stages, matched latency)
 
```
Stage 1 (registers on posedge):
    prod_reg  <= weight_reg * act_in      (multiply)
    act_reg1  <= act_in                    (activation, hop 1 of 2)
    psum_reg  <= psum_in                   (delay to stay aligned w/ prod_reg)
 
Stage 2 (registers on posedge):
    psum_out_reg <= psum_reg + prod_reg    (add)
    act_reg2     <= act_reg1               (activation, hop 2 of 2)
 
act_out  = act_reg2       -> 2 cycle latency
psum_out = psum_out_reg   -> 2 cycle latency
```
 
**Design decision: `act_out` and `psum_out` are deliberately matched to the
same 2-cycle latency**, via the extra `act_reg2` stage. This was not the
first version written - the first version had `act_out` at 1-cycle latency
while `psum_out` took 2, which is a real bug: the next PE in a Phase 2 grid
would receive an activation and a partial sum that came from two different
"waves" of input, one cycle apart, corrupting the sum it computes. Matching
the latencies means activation and partial-sum data move through the grid
in perfect lockstep - one PE hop costs exactly 2 cycles for *both* signals,
always. This is the same class of alignment bug as `psum_reg` delaying
`psum_in` to stay in sync with `prod_reg` inside a single PE - just one
level up, at the PE-to-PE boundary instead of inside one PE.
 
A value applied to `act_in`/`psum_in`, once actually sampled by the DUT's
stage-1 registers, takes 2 clock edges to appear on `act_out`/`psum_out`.
 
## Files
 
```
phase1_pe/
├── rtl/
│   └── pe.sv              -- the PE module
├── tb/
│   └── tb_pe.sv            -- self-checking testbench (20 checks)
├── scripts/
│   └── golden_check.py     -- independent Python cross-check of expected values
├── sim/                     -- compiled sim output (gitignored, generated)
└── Makefile
```
 
## Running it
 
Requires Icarus Verilog (`iverilog`/`vvp`):
```
sudo apt-get install iverilog gtkwave      # Linux
brew install icarus-verilog gtkwave         # macOS
```
 
```
iverilog -g2012 -o sim/tb_pe.vvp rtl/pe.sv tb/tb_pe.sv
vvp sim/tb_pe.vvp
```
 
Cross-check the expected scalar values independently:
```
python3 scripts/golden_check.py
```
 
## Test coverage (20 checks, all passing)
 
| Test                          | What it checks                                     |
|--------------------------------|-----------------------------------------------------|
| basic_positive_mac             | Simple correctness, all-positive operands, `psum_out` + `act_out` |
| accumulate_nonzero_psum        | `psum_in` is actually added, not overwritten        |
| negative_activation            | Signed handling, negative act                       |
| negative_weight                | Signed handling, negative weight                     |
| neg_times_neg                  | Sign logic: negative x negative = positive           |
| max_magnitude_operands         | -128 x -128 boundary case, no overflow/wraparound   |
| zero_weight_passthrough        | weight=0 -> psum_out should equal psum_in exactly   |
| zero_activation_passthrough    | act=0 -> psum_out should equal psum_in exactly      |
| continuous_act_in_flow (x4)    | **Continuous back-to-back streaming**: a new value on `act_in` every single cycle, no gaps, checked against `act_out` arriving exactly 2 cycles later for all 4 streamed values |
 
The first 8 are single-shot directed tests: apply one value, wait for the
known pipeline latency, check, move on. The last 4 (`continuous_act_in_flow`)
are a meaningfully different and stronger kind of test: they verify the PE
stays correctly pipelined when fed a **continuous stream** with zero gaps
between values - the actual condition the PE will operate under once
chained into a real array in Phase 2, where a new activation arrives every
cycle with no idle time between them. This test caught a real bug during
development: an early version of the loop only checked 2 of the 4 streamed
values because the loop exited before the last two results had time to
reach `act_out` - a good reminder that "the test passes" isn't the same as
"the test actually covers what you think it does."
 
## Design decisions worth remembering for an interview writeup
 
- **2-stage internal pipeline** (mult, then add) rather than a single-cycle
  MAC: splits what would likely be the critical path in a larger array, at
  the cost of extra latency and more careful skew management in Phase 2.
- **`act_out` latency matched to `psum_out` latency** (both 2 cycles, via
  an extra `act_reg2` stage): keeps activation and partial-sum data moving
  through the grid in lockstep, which simplifies Phase 2's skew math -
  every PE hop costs the same number of cycles for both signals.
- **Signed 8-bit operands, 32-bit accumulator**: matches how real int8
  quantized GEMM accelerators are built (int8 x int8 -> int32
  accumulation), not an arbitrary width choice.
- **Weight-stationary**: weight loaded once (gated by `load_weight`),
  reused across many MACs - minimizes weight re-reads at the cost of
  needing a separate load phase before streaming can start (built in
  Phase 2/3), as opposed to output-stationary designs where both operand
  matrices stream through the array on every computation.
## A verification lesson worth carrying into Phase 2
 
Getting the *timing* of a testbench right was consistently harder than
getting the PE's arithmetic right. Two real bugs surfaced purely from
testbench sequencing, not from the DUT:
 
1. Assigning `act_in = val; act_in = 0;` back-to-back with no clock edge
   between them is invisible to the DUT - both assignments happen in zero
   simulation time, so the hardware only ever sees the final value (`0`).
   Any two assignments to the same signal need a real `@(posedge/negedge
   clk)` between them if the DUT is meant to observe the intermediate
   value.
2. Moving *where* in a sequence a signal gets cleared changes how many
   cycles later a correct result should be checked - the required wait
   isn't a fixed constant tied only to "the pipeline is N stages," it
   depends on exactly when the stimulus was actually visible to the DUT's
   registers.
Both were only caught by compiling and simulating with real values printed
out - not by re-reading the code and reasoning about it abstractly. That's
the same discipline Phase 2 (grid-level skew) and Phase 4 (the full
verification suite) will lean on even more heavily.
 
## Next: Phase 2
 
Wire multiple PEs into a grid, get the activation skew right (empirically
confirmed to differ from a naive "just double everything" guess when
latencies change - verify with simulation, don't trust hand-derived
formulas blindly), and verify against a numpy-generated golden matrix