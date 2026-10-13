"""Runs a lab script as __main__ in its run dir (deploy/lab-run.sh --python SCRIPT).

On a gpu slot, caps torch's share of the card first (LAB_GPU_FRACTION, from the slot
count), since torch's caching allocator otherwise grows into memory other slots' jobs
need.

Process pools are capped to the slot: at most one worker per core of the affinity mask,
each worker's BLAS/OpenMP/torch threads the cores over the workers. Without it every
worker inherits OMP_NUM_THREADS (the whole slot), so --procs 6 on a 5-core slot ran ~30
threads on 5 cores, 3-4x slower and slowing the slot's neighbours.
"""

import concurrent.futures.process
import multiprocessing.pool
import os
import runpy
import sys

fraction = os.environ.get("LAB_GPU_FRACTION")
if fraction:
    import torch

    if torch.cuda.is_available():
        torch.cuda.set_per_process_memory_fraction(float(fraction))

if hasattr(os, "sched_getaffinity"):
    cores = len(os.sched_getaffinity(0))
else:
    cores = os.cpu_count() or 1


def limited(threads, initializer, initargs):
    from threadpoolctl import threadpool_limits

    os.environ["OMP_NUM_THREADS"] = str(threads)
    # Not a with-block: the limits stay for the worker's life
    threadpool_limits(threads)
    if "torch" in sys.modules:
        sys.modules["torch"].set_num_threads(threads)
    if initializer is not None:
        initializer(*initargs)


def share(kind, asked):
    n = min(asked or cores, cores)
    threads = max(1, cores // n)
    if asked and asked > n:
        print(f"labpy: {kind} of {asked} capped to {n} workers x {threads} threads"
              f" ({cores} cores)", file=sys.stderr)
    return n, threads


ppe_init = concurrent.futures.process.ProcessPoolExecutor.__init__


def ppe(self, max_workers=None, mp_context=None, initializer=None, initargs=(), **kw):
    n, threads = share("ProcessPoolExecutor", max_workers)
    ppe_init(self, n, mp_context, limited, (threads, initializer, initargs), **kw)


pool_init = multiprocessing.pool.Pool.__init__


def pool(self, processes=None, initializer=None, initargs=(), *a, **kw):
    # ThreadPool runs Pool's __init__ too, and its workers share this process
    if isinstance(self, multiprocessing.pool.ThreadPool):
        return pool_init(self, processes, initializer, initargs, *a, **kw)
    n, threads = share("Pool", processes)
    pool_init(self, n, limited, (threads, initializer, initargs), *a, **kw)


concurrent.futures.process.ProcessPoolExecutor.__init__ = ppe
multiprocessing.pool.Pool.__init__ = pool

if __name__ == "__main__":
    sys.argv = sys.argv[1:]
    sys.path.insert(0, os.getcwd())
    runpy.run_path(sys.argv[0], run_name="__main__")
