"""Reproduce the finite tables of ePrint 2019/316 from published inputs."""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from itertools import product
from math import prod
from pathlib import Path
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from compiled import load_kernel
from ea_catalogue import analyze, permutation_correction, orders, linear_table
from affine_oracle import affine_permutations, ea_orbit
from ea_equivalence import algebraic_degree
from walsh import absolute_walsh_spectrum, algebraic_degree_by_subsets
from code_classification import canonical_code, equivalent_permutation, lift_graph_permutation, affine_table


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def validate_correction(table, correction):
    if correction is not None:
        require(affine_table(correction, linear=True), 'correction is not linear')
        require(sorted(a ^ b for a, b in zip(table, correction)) == list(range(len(table))),
                'correction does not yield a permutation')


def small_checks(kernel, inputs):
    checks = []
    for n in (1, 2):
        q = 1 << n
        group = tuple(affine_permutations(n))
        affine_maps = [tuple(y ^ columns[0] for y in linear_table(columns[1:]))
                       for columns in product(range(q), repeat=n+1)]
        for row in inputs[n-1]['representatives']:
            table = tuple(row['table'])
            orbit = ea_orbit(table, group, affine_maps)
            result = kernel.analyze(table)
            require(result['canonical'] and min(orbit) == table, 'tiny canonical oracle differs')
            require(orders(table, result['input_stabilizer'])['orbit_size'] == len(orbit),
                    'tiny orbit-size oracle differs')
        # All normalized tables, including nonminimal ones.
        free = [x for x in range(q) if x != 0 and x & (x-1)]
        for values in product(range(q), repeat=len(free)):
            table = [0] * q
            for x, y in zip(free, values):
                table[x] = y
            actual, expected = kernel.analyze(table), analyze(table)
            require(all(actual[k] == expected[k] for k in expected), 'reference differs')
        checks.append(dict(check='complete_small_EA_action', dimension=n))
    for row in inputs[2]['representatives']:
        table = row['table']
        actual, expected = kernel.analyze(table), analyze(table)
        require(all(actual[k] == expected[k] for k in expected), 'n=3 full-map reference differs')
        a, b = kernel.permutation_correction(table), permutation_correction(table)
        require((a is None) == (b is None), 'linear-correction reference differs')
        validate_correction(table, a)
        validate_correction(table, b)
    checks.append(dict(check='n3_reference_full_maps_and_linear_corrections', rows=7))
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--max-dimension', type=int, choices=[3, 4], default=4)
    parser.add_argument('--reference', action='store_true', help='use readable full-map enumeration (slow for n=4)')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    start = time.perf_counter()
    inputs = json.loads((ROOT / 'data/ea-ccz-2019.json').read_text())
    kernel, build = load_kernel('ea_catalogue') if not args.reference else (None, None)
    checks = small_checks(kernel, inputs['dimensions']) if kernel else []
    analyze_function = analyze if kernel is None else kernel.analyze
    correction_function = permutation_correction if kernel is None else kernel.permutation_correction
    dimensions = []
    for dimension in inputs['dimensions'][:args.max_dimension]:
        n = dimension['dimension']
        q = 1 << n
        rows = dimension['representatives']
        require([r['table'] for r in rows] == sorted(r['table'] for r in rows) and
                len({tuple(r['table']) for r in rows}) == len(rows), 'rows must be sorted and distinct')
        records, canonical_groups, class_rows = [], {}, []
        orbit_sum = 0
        expected_maps = q * prod(q - (1 << i) for i in range(n))
        then = time.perf_counter()
        last = then
        for row in rows:
            index, table = row['row'], row['table']
            analysis = analyze_function(table)
            require(analysis['canonical'], 'EA noncanonical n={} row={}'.format(n, index))
            if 'affine_maps' in analysis:
                require(analysis['affine_maps'] == expected_maps, 'affine enumeration incomplete')
            sizes = orders(table, analysis['input_stabilizer'])
            require(sizes['stabilizer_order'] == row['stabilizer'], 'stabilizer differs')
            degree = max(1, algebraic_degree(table))
            require(degree == row['degree'] == max(1, algebraic_degree_by_subsets(table)), 'degree differs')
            spectrum = absolute_walsh_spectrum(table)
            require(spectrum == absolute_walsh_spectrum(table, method='direct'), 'Walsh methods differ')
            require([spectrum.get(i, 0) for i in range(q+1)] == row['walsh'], 'published spectrum differs')
            correction = correction_function(table)
            validate_correction(table, correction)
            require((correction is not None) == row['bijective'], 'bijection flag differs')
            info = canonical_code(table)
            # Fingerprints only select buckets. Equality of complete canonical
            # graphs, checked by equivalent_permutation, makes the decision.
            bucket = canonical_groups.setdefault(info['fingerprint'], [])
            permutation, target_row = None, None
            for rep_row, rep_info in bucket:
                permutation = equivalent_permutation(info, rep_info)
                if permutation is not None:
                    target_row = rep_row
                    break
            if permutation is None:
                target_row = index
                bucket.append((index, info))
                class_rows.append(index)
                witness = None
            else:
                witness = lift_graph_permutation(table, rows[target_row-1]['table'], permutation)
            require(target_row == row['ccz_row'], 'CCZ assignment differs n={} row={}'.format(n, index))
            records.append(dict(row=index, canonical=True, input_stabilizer=analysis['input_stabilizer'],
                                **sizes, degree=degree, walsh=row['walsh'],
                                permutation_correction=correction, ccz_row=target_row,
                                ccz_permutation=permutation, ccz_witness=witness))
            orbit_sum += sizes['orbit_size']
            now = time.perf_counter()
            if now-last >= 20 or index == len(rows):
                print('n={}: {}/{} EA rows, {} CCZ classes, {:.1f}s'.format(
                    n, index, len(rows), len(class_rows), now-then), file=sys.stderr, flush=True)
                last = now
        require(orbit_sum == q**q, 'EA orbit sizes do not cover all functions')
        dimensions.append(dict(dimension=n, rows=records, ea_classes=len(rows),
                               ccz_classes=len(class_rows), ccz_representative_rows=class_rows,
                               bijective_classes=sum(r['permutation_correction'] is not None for r in records),
                               distinct_orbit_sizes=len({r['orbit_size'] for r in records}),
                               distinct_walsh_spectra=len({tuple(r['walsh']) for r in records}),
                               orbit_sum=orbit_sum, all_functions=q**q,
                               seconds=time.perf_counter()-then))
    sources = ['sage/ea_ccz_catalogue.sage', 'sage/import_ea_ccz_2019.py',
               'lib/ea_catalogue.py', 'cython/ea_catalogue.pyx', 'lib/compiled.py',
               'lib/affine_oracle.py', 'lib/ea_equivalence.py', 'lib/affine_refinement.py',
               'lib/code_classification.py', 'lib/apn_reference.py', 'lib/walsh.py',
               'data/ea-ccz-2019.json']
    result = dict(schema=1, artifact='ea-ccz-catalogue-2019', completed=True,
                  finished_utc=datetime.now(timezone.utc).isoformat(),
                  environment=dict(sage=SAGE_VERSION, python=platform.python_version(),
                                   system=platform.system(), machine=platform.machine()),
                  configuration=dict(max_dimension=args.max_dimension, reference=args.reference,
                                     method='full affine-input enumeration, greedy linear output minimization; CCZ via Bliss'),
                  source_sha256={p:hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources},
                  input_provenance=inputs['source'], build=build, checks=checks, dimensions=dimensions,
                  elapsed_seconds=time.perf_counter()-start)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix('.tmp')
    temporary.write_text(json.dumps(result, indent=2, sort_keys=True, default=int)+'\n')
    temporary.replace(args.output)


if __name__ == '__main__':
    main()
