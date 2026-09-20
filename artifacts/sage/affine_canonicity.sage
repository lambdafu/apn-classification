"""Verify affine canonicity and reproduce the dimension-four EA classification."""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from itertools import product, permutations as all_permutations
from pathlib import Path

from sage.all import GF, MatrixSpace, VectorSpace, matrix
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from affine_canonicity import smaller_witness, search_apn
from affine_oracle import (affine_permutations, exhaustive_smaller,
                           comparable_smaller, affine_orbit, ea_orbit,
                           affine_canonical_by_full_maps)
from ea_equivalence import equivalence_witness, algebraic_degree
from apn_reference import is_apn_derivatives


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def encode(v):
    return int(sum(int(bit) << i for i, bit in enumerate(v)))


def sage_maps(n):
    V = VectorSpace(GF(2), n)
    points = [V([(x >> i) & 1 for i in range(n)]) for x in range(1 << n)]
    maps, bijections = set(), set()
    for M in MatrixSpace(GF(2), n, n):
        for shift in V:
            table = tuple(encode(M * x + shift) for x in points)
            maps.add(table)
            if M.is_invertible():
                bijections.add(table)
    return maps, bijections


def validate_affine(table, n, injective):
    V = VectorSpace(GF(2), n)
    points = [V([(x >> i) & 1 for i in range(n)]) for x in range(1 << n)]
    require(len(table) == len(points) and all(0 <= v < len(points) for v in table),
            'invalid witness table')
    offset = points[table[0]]
    M = matrix(GF(2), [points[table[1 << i]] + offset for i in range(n)]).transpose()
    require(all(M * points[x] + offset == points[table[x]] for x in range(len(points))),
            'witness is not affine')
    require(not injective or M.is_invertible(), 'witness is not invertible')


def validate_ea(source, target, witness, n):
    alpha, beta, gamma = witness
    for table, injective in ((alpha, True), (beta, True), (gamma, False)):
        validate_affine(table, n, injective)
    V = VectorSpace(GF(2), n)
    points = [V([(x >> i) & 1 for i in range(n)]) for x in range(1 << n)]
    require(all(points[beta[source[alpha[x]]]] + points[gamma[x]] == points[target[x]]
                for x in range(len(source))), 'EA witness equation fails')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    start = time.perf_counter()
    expected = json.loads((ROOT / 'data/dimension-four.json').read_text())
    checks = []
    for n in range(1, 3):
        q = 1 << n
        maps, bijections = sage_maps(n)
        group = sorted(bijections)
        require(set(affine_permutations(n)) == bijections, 'basis and matrix groups differ')
        count = rejected = 0
        for d in range(q + 1):
            for prefix in product(range(q), repeat=d):
                witness = smaller_witness(prefix, n)
                require((witness is not None) == exhaustive_smaller(prefix, group),
                        'partial filter and full affine action disagree')
                if witness is not None:
                    for table in witness:
                        validate_affine(table, n, True)
                    require(comparable_smaller(prefix, *witness), 'invalid rejection witness')
                    rejected += 1
                if d == q:
                    require((witness is None) == affine_canonical_by_full_maps(prefix, n),
                            'greedy output oracle disagrees with full group action')
                count += 1
        checks.append(dict(check='all_prefixes_affine_action', dimension=n,
                           prefixes=count, rejections=rejected, group_order=len(group)))
        # An independent complete EA partition checks both success and failure
        # of the three-template search, not merely positive examples.
        functions = set(product(range(q), repeat=q))
        orbits = []
        remaining = set(functions)
        while remaining:
            representative = min(remaining)
            orbit = ea_orbit(representative, group, maps)
            require(orbit <= remaining, 'EA oracle orbits overlap')
            orbits.append((representative, orbit))
            remaining -= orbit
        tests = 0
        for target, orbit in orbits:
            for source in sorted(functions):
                witness = equivalence_witness(source, target)
                require((witness is not None) == (source in orbit), 'EA oracle disagreement')
                if witness is not None:
                    validate_ea(source, target, witness, n)
                tests += 1
        checks.append(dict(check='complete_ea_partition', dimension=n,
                           orbit_sizes=[len(o) for _, o in orbits], pairs_checked=tests))
        print('n={}: all {} prefixes and {} EA equivalence cases verified'.format(n, count, tests),
              file=sys.stderr, flush=True)

    # Independent permutation-only enumeration and complete affine orbit in n=3.
    group3 = tuple(affine_permutations(int(3)))
    oracle_permutations = {p for p in all_permutations(range(8)) if is_apn_derivatives(p)}
    permutation3 = tuple(expected['permutation_n3'])
    require(affine_orbit(permutation3, group3) == oracle_permutations,
            'dimension-three orbit does not cover exactly the APN permutations')
    require(len(oracle_permutations) == 10752, 'APN permutation count mismatch')
    permutation_results = []
    for n in (int(3), int(4)):
        stats = {}
        then = time.perf_counter()
        representatives = list(search_apn(n, permutations=True, stats=stats))
        require(representatives == ([permutation3] if n == 3 else []),
                'APN permutation representatives disagree')
        permutation_results.append(dict(dimension=n, representatives=representatives,
                                        search=stats, seconds=time.perf_counter() - then))
    print('APN permutation classification verified in n=3,4', file=sys.stderr, flush=True)

    then = time.perf_counter()
    stats = {}
    candidates = list(search_apn(int(4), normalized=True, stats=stats))
    search_seconds = time.perf_counter() - then
    require(candidates == sorted(set(candidates)), 'unordered or duplicate candidates')
    require(all(is_apn_derivatives(s) for s in candidates), 'candidate is not APN')
    require(all(affine_canonical_by_full_maps(s, int(4)) for s in candidates),
            'candidate fails independent complete affine canonicity test')

    # Determine classes from the computed list, without feeding published
    # representatives into the classification algorithm.
    representatives, degrees, assignments = [], [], []
    for candidate in candidates:
        degree = algebraic_degree(candidate)
        witness = None
        for class_id, (representative, rep_degree) in enumerate(zip(representatives, degrees)):
            if degree != rep_degree:  # APN candidates here have degree >= 2.
                continue
            witness = equivalence_witness(candidate, representative)
            if witness is not None:
                break
        if witness is None:
            class_id = len(representatives)
            representatives.append(candidate)
            degrees.append(degree)
            identity = tuple(range(16))
            witness = (identity, identity, (int(0),) * 16)
        validate_ea(candidate, representatives[class_id], witness, int(4))
        assignments.append(dict(candidate=candidate, degree=degree, ea_class=class_id,
                                alpha=witness[0], beta=witness[1], gamma=witness[2]))
    require([list(s) for s in representatives] == expected['ea_representatives'],
            'published EA representatives differ')
    require(degrees == expected['ea_degrees'], 'published degrees differ')
    # Different degrees prove inequivalence here; no timed-out negative tests.
    require(len(set(degrees)) == len(degrees) and min(degrees) >= 2,
            'degree-based inequivalence argument does not apply')
    discrepancy = dict(reported=expected['reported_weak_ea_candidates'],
                       computed=len(candidates), matches=len(candidates) == expected['reported_weak_ea_candidates'],
                       status='historical intermediate count unresolved')
    print('n=4: {} weak candidates (publication: {}); {} EA classes with verified witnesses'.format(
          len(candidates), discrepancy['reported'], len(representatives)), file=sys.stderr, flush=True)
    inputs = ['sage/affine_canonicity.sage', 'lib/affine_canonicity.py',
              'lib/affine_refinement.py', 'lib/affine_oracle.py', 'lib/ea_equivalence.py',
              'lib/apn_reference.py', 'data/dimension-four.json']
    record = dict(schema=1, artifact='affine-canonicity', completed=True,
                  finished_utc=datetime.now(timezone.utc).isoformat(),
                  environment=dict(sage=SAGE_VERSION, python=platform.python_version(),
                                   system=platform.system(), machine=platform.machine()),
                  configuration=dict(dimension=4, canonicity_cutoff=None,
                                     oracle_prefix_dimensions=[1, 2]),
                  source_sha256={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                 for name in inputs},
                  checks=checks, permutation_classification=permutation_results,
                  dimension_four=dict(search=stats, search_seconds=search_seconds,
                                      candidates=candidates, ea_representatives=representatives,
                                      assignments=assignments, candidate_count=discrepancy,
                                      full_affine_maps_per_candidate=322560),
                  elapsed_seconds=time.perf_counter() - start)
    candidate_text = (
        '# Dimension 4: reconstructed weak EA candidates, in lexicographic order.\n'
        '# Computed count: {}. Publications report {}. Historical list not recovered.\n'
        '# Each data row is s(0), ..., s(15), as space-separated decimal integers.\n'
    ).format(len(candidates), expected['reported_weak_ea_candidates'])
    candidate_text += ''.join(' '.join(str(v) for v in table) + '\n' for table in candidates)
    if args.output:
        candidate_path = args.output.with_name('dimension-four-weak-ea-candidates.txt')
        record['outputs'] = dict(candidate_tables=dict(
            filename=candidate_path.name, count=len(candidates),
            sha256=hashlib.sha256(candidate_text.encode('utf8')).hexdigest()))
    rendered = json.dumps(record, indent=2, sort_keys=True, default=int) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        candidate_temporary = candidate_path.with_name(candidate_path.name + '.tmp')
        candidate_temporary.write_text(candidate_text, encoding='utf8')
        candidate_temporary.replace(candidate_path)
        temporary = args.output.with_name(args.output.name + '.tmp')
        temporary.write_text(rendered)
        temporary.replace(args.output)
    else:
        print(rendered, end='')


if __name__ == '__main__':
    main()
