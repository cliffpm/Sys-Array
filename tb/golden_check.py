#!/usr/bin/env python3
"""
golden_check.py - Independent Python cross-check for the Phase 1 PE tests.

This isn't required for Phase 1 (the SV testbench is fully self-checking),
but it establishes the golden-model pattern you'll rely on much more heavily
starting in Phase 2, where hand-deriving expected matrix products stops
being practical and you'll generate expected results here and feed them
into the SV testbench via $readmemh.

Run: python3 golden_check.py
"""

test_cases = [
    # (weight, act, psum_in, test_name)
    (5,   3,   0,   "basic_positive_mac"),
    (5,   4,   100, "accumulate_nonzero_psum"),
    (5,  -3,   0,   "negative_activation"),
    (-7,  6,   0,   "negative_weight"),
    (-7, -6,   0,   "neg_times_neg"),
    (-128, -128, 0, "max_magnitude_operands"),
    (0,  127,  500, "zero_weight_passthrough"),
    (9,   0,   77,  "zero_activation_passthrough"),
]

def main():
    print("Golden model cross-check for pe.sv test vectors\n")
    all_ok = True
    for weight, act, psum_in, name in test_cases:
        expected = psum_in + (weight * act)
        print(f"{name:30s}: weight={weight:5d} act={act:5d} psum_in={psum_in:6d} "
              f"-> expected psum_out={expected}")
    print("\nCompare these against the [PASS]/[FAIL] lines from `make sim`.")
    print("If they diverge, trust this Python model over hand-derived SV")
    print("expectations - that's the whole point of a golden model.")

if __name__ == "__main__":
    main()