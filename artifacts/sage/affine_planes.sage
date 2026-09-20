"""Verify affine plane counts, prefix recurrences, and finite extremal bounds."""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from sage.all import GF, VectorSpace, binomial
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))
from affine_geometry import planes_in, prefix_count, new_plane_count, subset_extrema


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sage_planes(n):
    """Independent construction: cosets of actual rank-two Sage subspaces."""
    if n < 2:
        return set()
    V = VectorSpace(GF(2), n)
    result = set()
    for linear in V.subspaces(2):
        for t in V:
            coset = tuple(sorted(sum(int(bit) << i for i, bit in enumerate(t + u))
                                 for u in linear))
            result.add(coset)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-dimension", type=int, choices=range(1, 6), default=5)
    parser.add_argument("--subset-dimension", type=int, choices=range(1, 5), default=4)
    parser.add_argument("--output", type=Path, help="completed JSON run record")
    args = parser.parse_args()
    start = time.perf_counter()
    expected = json.loads((ROOT / "data/affine-planes.json").read_text())
    rows = []
    for n in range(1, args.max_dimension + 1):
        q = int(1 << n)
        then = time.perf_counter()
        planes = planes_in(range(q))
        require(set(planes) == sage_planes(n), "four-point and Sage coset sets differ")
        require(len(planes) == binomial(q, 3) / 4, "total count formula fails")
        A = [prefix_count(k) for k in range(q + 1)]
        delta = [new_plane_count(k) for k in range(q + 1)]
        for k in range(q + 1):
            direct = sum(max(p) < k for p in planes)
            newly_completed = sum(max(p) == k - 1 for p in planes)
            require(A[k] == direct and delta[k] == newly_completed,
                    "recurrences disagree with enumeration")
            require(k == 0 or delta[k] == A[k] - A[k - 1], "Delta index mismatch")
        # A plane-level check implies the decomposition for every contained subset.
        cases = 0
        for a in range(1, q):
            for plane in planes:
                sides = sum((a & x).bit_count() % 2 for x in plane)
                require(sides in (0, 2, 4), "hyperplane decomposition fails")
                cases += 1
        row = {"dimension": n, "planes": len(planes), "prefix_counts": A,
               "new_plane_counts": delta, "hyperplane_plane_pairs_checked": cases}
        if n <= args.subset_dimension:
            extrema = subset_extrema(n, planes)
            require(extrema["maxima"] == A, "extremal bound fails")
            row["all_subsets"] = extrema
        if n == 3:
            require([list(p) for p in planes] == expected["example_3_3"],
                    "thesis Example 3.3 differs")
        if n >= 4:
            require(A[1:17] == expected["article_eq_20"], "article A sequence differs")
            require(delta[1:17] == expected["article_eq_21"], "article Delta sequence differs")
        row["seconds"] = time.perf_counter() - then
        rows.append(row)
        print("n={}: {} planes; all {} prefixes verified{}".format(
            n, len(planes), q + 1,
            "; all {} subsets checked".format(1 << q) if n <= args.subset_dimension else ""),
            file=sys.stderr, flush=True)
    for example in expected["example_3_12"]:
        require(len(planes_in(example["points"])) == example["planes"],
                "thesis Example 3.12 differs")
    inputs = ["sage/affine_planes.sage", "lib/affine_geometry.py", "data/affine-planes.json"]
    record = {"schema": 1, "artifact": "affine-planes", "completed": True,
              "finished_utc": datetime.now(timezone.utc).isoformat(),
              "environment": {"sage": SAGE_VERSION, "python": platform.python_version(),
                              "system": platform.system(), "machine": platform.machine()},
              "configuration": {"max_dimension": args.max_dimension,
                                "subset_dimension": min(args.subset_dimension, args.max_dimension)},
              "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                for name in inputs},
              "results": rows, "example_3_12_checked": True,
              "elapsed_seconds": time.perf_counter() - start}
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

