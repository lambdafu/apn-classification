"""Check affine refinement against independently enumerated Sage matrices."""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from sage.all import GF, MatrixSpace, VectorSpace
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "lib"))
from affine_refinement import empty_template, refine, complete


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def encode(v):
    return int(sum(int(bit) << i for i, bit in enumerate(v)))


def matrix_tables(n):
    """Full oracle x -> M*x+b, using Sage matrix/vector arithmetic."""
    F = GF(2)
    V = VectorSpace(F, n)
    points = [V([(x >> i) & 1 for i in range(n)]) for x in range(1 << n)]
    tables = set()
    invertible = set()
    for M in MatrixSpace(F, n, n):
        bijective = M.is_invertible()
        for b in V:
            table = tuple(encode(M * x + b) for x in points)
            tables.add(table)
            if bijective:
                invertible.add(table)
    return tables, invertible


def affine_domains(n):
    V = VectorSpace(GF(2), n)
    domains = {()}
    for d in range(n + 1):
        for U in V.subspaces(d):
            for b in V:
                domains.add(tuple(sorted(encode(x + b) for x in U)))
    return domains


def compatible(table, full):
    return all(y is None or full[x] == y for x, y in enumerate(table))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-dimension", type=int, choices=[1, 2, 3], default=3)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    start = time.perf_counter()
    rows = []
    for n in range(1, args.max_dimension + 1):
        then = time.perf_counter()
        q = int(1 << n)
        tables, permutations = matrix_tables(n)
        require(len(tables) == q ** (n + 1), "matrix oracle count mismatch")
        expected_permutations = q
        for i in range(n):
            expected_permutations *= q - (1 << i)
        require(len(permutations) == expected_permutations, "affine group order mismatch")
        # Every affine map, including singular maps, on two distinct affine bases.
        # The translated basis exercises domains not initially containing zero.
        standard = [int(0)] + [int(1 << i) for i in range(n)]
        translated = [int(q - 1 - x) for x in standard]  # XOR with all-one vector
        reconstructions = 0
        for full in tables:
            for basis in (standard, translated):
                partial = empty_template(n)
                for point in basis:
                    old = partial
                    partial = refine(partial, point, full[point])
                    require(partial is not None and compatible(partial, full),
                            "refinement contradicts matrix oracle")
                    require(compatible(old, partial), "refinement changed a fixed value")
                require(partial == full, "affine basis did not reconstruct full map")
                reconstructions += 1

        row = {"dimension": n, "affine_maps": len(tables),
               "affine_permutations": len(permutations),
               "basis_reconstructions": reconstructions}
        if n <= 2:
            # All affine domains, all affine restrictions, every assignment,
            # and both injectivity modes. Expected answers come from filtering
            # the complete matrix oracle, not from another closure algorithm.
            domains = affine_domains(n)
            templates = set()
            for domain in domains:
                for full in tables:
                    templates.add(tuple(full[x] if x in domain else None for x in range(q)))
            transitions = 0
            completions = 0
            for partial in templates:
                for injective in (False, True):
                    oracle = permutations if injective else tables
                    extensions = {full for full in oracle if compatible(partial, full)}
                    completed = complete(partial, injective=injective)
                    require((completed is None) == (not extensions), "completion existence mismatch")
                    if completed is not None:
                        require(completed in extensions, "invalid affine completion")
                    completions += 1
                    for point in range(q):
                        for value in range(q):
                            expected = {full for full in extensions if full[point] == value}
                            result = refine(partial, point, value, injective=injective)
                            require((result is None) == (not expected), "refinement feasibility mismatch")
                            if result is not None:
                                actual = {full for full in oracle if compatible(result, full)}
                                require(actual == expected, "refinement changes compatible maps")
                                # No missing implications: a value is determined exactly
                                # on the affine hull of old domain plus the new point.
                                old_domain = {x for x in range(q) if partial[x] is not None}
                                enclosing = [set(D) for D in domains if old_domain | {point} <= set(D)]
                                hull = set.intersection(*enclosing)
                                require({x for x in range(q) if result[x] is not None} == hull,
                                        "refinement domain is not the affine hull")
                            transitions += 1
            row.update(templates_checked=len(templates), transitions_checked=transitions,
                       completions_checked=completions)
        row["seconds"] = time.perf_counter() - then
        rows.append(row)
        print("n={}: {} affine maps; {} basis reconstructions verified{}".format(
            n, len(tables), reconstructions,
            "; all template transitions checked" if n <= 2 else ""), file=sys.stderr, flush=True)
    inputs = ["sage/affine_refinement.sage", "lib/affine_refinement.py"]
    record = {"schema": 1, "artifact": "affine-refinement", "completed": True,
              "finished_utc": datetime.now(timezone.utc).isoformat(),
              "environment": {"sage": SAGE_VERSION, "python": platform.python_version(),
                              "system": platform.system(), "machine": platform.machine()},
              "configuration": {"max_dimension": args.max_dimension,
                                "all_template_transition_dimensions": list(range(1, min(2, args.max_dimension) + 1))},
              "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                for name in inputs},
              "results": rows, "elapsed_seconds": time.perf_counter() - start}
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
