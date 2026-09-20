"""Reproduce the small APN counts; run with sage sage/apn_counts.sage --help.

This file also works with `sage -python`: all hot loops live in ordinary
Python so Sage preparsing does not change integer XOR into exponentiation.
"""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from itertools import product
from pathlib import Path

from sage.all import GF, VectorSpace
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))
from apn_reference import enumerate_apn, is_apn_derivatives, is_apn_planes


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def is_apn_vectors(table, n):
    """Literal Sage vector-space version of Definition 4.1."""
    V = VectorSpace(GF(2), n)
    points = [V([(x >> i) & 1 for i in range(n)]) for x in range(1 << n)]
    positions = {tuple(v): i for i, v in enumerate(points)}
    for a in points[1:]:
        counts = {}
        for i, x in enumerate(points):
            j = positions[tuple(x + a)]
            difference = tuple(points[table[i]] + points[table[j]])
            counts[difference] = counts.get(difference, 0) + 1
        if max(counts.values()) > 2:
            return False
    return True


def summarize(tables, q, serialized=None):
    """Hash all tables, also requiring valid ranges and strict ordering."""
    digest = hashlib.sha256()
    count = permutations = 0
    previous = None
    for table in tables:
        row = bytes(table)
        require(len(row) == q and all(v < q for v in row), "invalid table")
        require(previous is None or previous < row, "duplicate or unordered table")
        digest.update(row)
        if serialized is not None:
            serialized.extend(row)
        count += 1
        permutations += len(set(row)) == q
        previous = row
    return {"count": count, "permutations": permutations,
            "tables_sha256": digest.hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-dimension", type=int, choices=[1, 2, 3], default=3)
    parser.add_argument("--cython", action="store_true",
                        help="compare compiled incremental and unpruned searches")
    parser.add_argument("--output", type=Path, help="write a JSON run record")
    args = parser.parse_args()
    start = time.perf_counter()
    expected = json.loads((ROOT / "data/apn-counts.json").read_text())
    checks = []

    # This finite check validates the representation as well as the predicates.
    # It is exhaustive in n <= 2; it is not a proof for arbitrary dimensions.
    for n in range(1, min(2, args.max_dimension) + 1):
        q = 1 << n
        accepted = []
        for table in product(range(q), repeat=q):
            direct = is_apn_vectors(table, n)
            require(direct == is_apn_derivatives(table) == is_apn_planes(table),
                    "independent APN predicates disagree")
            if direct:
                accepted.append(table)
        require(accepted == list(enumerate_apn(n)), "reference search misses tables")
        checks.append({"check": "all_functions_three_predicates", "dimension": n,
                       "functions_checked": q ** q})

    rows = []
    kernel = build = None
    if args.cython:
        from compiled import load_kernel
        kernel, build = load_kernel("apn_counts")
    for n in range(1, args.max_dimension + 1):
        q = 1 << n
        stats = {}
        then = time.perf_counter()
        reference_tables = bytearray() if kernel else None
        reference = summarize(enumerate_apn(n, stats), q, reference_tables)
        target = expected["counts"][str(n)]
        require(reference["count"] == target["apn"], "published APN count mismatch")
        require(reference["permutations"] == target["permutations"],
                "APN permutation count mismatch")
        row = {"dimension": n, "reference": reference, "search": stats,
               "reference_seconds": time.perf_counter() - then}
        if kernel:
            row["cython"] = {}
            for method in ("incremental", "exhaustive"):
                then = time.perf_counter()
                data, reported = kernel.enumerate_tables(int(n), method)
                elapsed = time.perf_counter() - then
                require(len(data) % q == 0, "truncated Cython output")
                require(data == reference_tables, "Cython and reference truth tables differ")
                actual = summarize((data[i:i + q] for i in range(0, len(data), q)), q)
                require(actual == reference, "Cython and reference output disagree")
                require(reported["count"] == actual["count"] and
                        reported["permutations"] == actual["permutations"],
                        "Cython summary disagrees with its output")
                if method == "incremental":
                    require(all(reported[key] == stats[key] for key in stats),
                            "reference and Cython search profiles disagree")
                row["cython"][method] = {**reported, "tables_sha256": actual["tables_sha256"],
                                    "seconds_with_output": elapsed}
        rows.append(row)
        print("n={}: {} APN functions, {} permutations; {}".format(
            n, reference["count"], reference["permutations"],
            "Sage reference + two Cython methods agree" if kernel else "Sage reference"),
            file=sys.stderr, flush=True)

    inputs = ["sage/apn_counts.sage", "lib/apn_reference.py", "data/apn-counts.json"]
    if kernel:
        inputs += ["cython/apn_counts.pyx", "Makefile", "lib/compiled.py"]
    record = {"schema": 2, "artifact": "apn-counts", "completed": True,
              "finished_utc": datetime.now(timezone.utc).isoformat(),
              "environment": {"sage": SAGE_VERSION, "python": platform.python_version(),
                              "system": platform.system(), "machine": platform.machine()},
              "configuration": {"max_dimension": args.max_dimension,
                                "cython_comparison": bool(kernel)},
              "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                for name in inputs},
              "checks": checks, "results": rows,
              "elapsed_seconds": time.perf_counter() - start}
    if kernel:
        record["build"] = build
    # The .sage preparser creates exact Sage Integers from numeric literals.
    rendered = json.dumps(record, indent=2, sort_keys=True, default=int) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_name(args.output.name + ".tmp")
        temporary.write_text(rendered)
        temporary.replace(args.output)
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
