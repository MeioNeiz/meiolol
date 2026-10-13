"""Runs a lab script as __main__ in its run dir (deploy/lab-run.sh --python SCRIPT).

On a gpu slot, caps torch's share of the card first (LAB_GPU_FRACTION, from the slot
count), since torch's caching allocator otherwise grows into memory other slots' jobs
need.
"""

import os
import runpy
import sys

fraction = os.environ.get("LAB_GPU_FRACTION")
if fraction:
    import torch

    if torch.cuda.is_available():
        torch.cuda.set_per_process_memory_fraction(float(fraction))

sys.argv = sys.argv[1:]
sys.path.insert(0, os.getcwd())
runpy.run_path(sys.argv[0], run_name="__main__")
