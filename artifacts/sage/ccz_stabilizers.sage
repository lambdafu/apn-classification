"""Verify CCZ classes and full EA stabilizers of the published n=4,5 inputs.

This does not classify the full dimension-five construction candidate set.
"""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import sage.all  # Initialize Sage before importing its libgap extension.
from sage.env import SAGE_VERSION
from sage.libs.gap.libgap import libgap

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from apn_reference import is_apn_derivatives
from ea_equivalence import algebraic_degree
from code_classification import (affine_input_group, binary_rank, canonical_code, ea_group_order,
                                 ea_stabilizer, equivalent_permutation,
                                 lift_graph_permutation, require)
from verify_code_classification import verify_reductions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    start = time.perf_counter()
    checks = verify_reductions()
    print('Small CCZ orbits, rank-deficient graph lifts, and exhaustive n=3 EA stabilizer verified',
          file=sys.stderr, flush=True)
    inputs4 = json.loads((ROOT / 'data/dimension-four.json').read_text())
    inputs5 = json.loads((ROOT / 'data/dimension-five.json').read_text())
    cases = [(int(4), inputs4['ea_representatives'], [5760, 384], [1, 1], int(18940805775360)),
             (int(5), [r['table'] for r in inputs5['representatives']],
              [r['reported_ea_stabilizer_order'] for r in inputs5['representatives']],
              [r['reported_ccz_representative'] for r in inputs5['representatives']],
              int(110823678910407691468800))]
    results = []
    for n, tables, expected_orders, expected_classes, reported_total in cases:
        group = affine_input_group(n)
        infos = [canonical_code(table) for table in tables]
        representative_indices = []
        assignments = []
        for i, info in enumerate(infos):
            representative = next((j for j in representative_indices
                                   if info['canonical_graph'] == infos[j]['canonical_graph']), None)
            if representative is None:
                representative_indices.append(i)
                representative = i
            p = equivalent_permutation(info, infos[representative])
            transform = lift_graph_permutation(tables[i], tables[representative], p)
            assignments.append(dict(id=i + 1, representative=representative + 1,
                                    permutation=p, augmented_graph_map=transform))
        require([a['representative'] for a in assignments] == expected_classes,
                'computed CCZ partition differs from publication')
        # Every pair: exact canonical graph equality, with checked positive
        # graph maps. Distinct canonical forms are completed negative tests.
        pairs = []
        for i in range(len(tables)):
            for j in range(i + 1, len(tables)):
                p = equivalent_permutation(infos[i], infos[j])
                if p is not None:
                    lift_graph_permutation(tables[i], tables[j], p)
                pairs.append(dict(source=i + 1, target=j + 1, equivalent=p is not None))
        stabilizers = []
        for i, (table, info, expected) in enumerate(zip(tables, infos, expected_orders)):
            then = time.perf_counter()
            require(is_apn_derivatives(table), 'input fails direct APN check')
            require(all(table[x] == 0 for x in [0] + [int(1 << j) for j in range(n)]),
                    'published zero affine basis fails')
            require(binary_rank(table) == n, 'published image does not span output')
            result = ea_stabilizer(table, info, group)
            require(result['ea_stabilizer_order'] == expected, 'EA stabilizer order differs from publication')
            # The dual has exactly the same coordinate automorphisms. Sage's
            # automorphism routine uses the smaller-dimensional representation.
            dual_group = info['code'].dual_code().permutation_automorphism_group(algorithm='partition')
            row_group = info['code'].permutation_automorphism_group(algorithm='partition')
            require(dual_group == row_group, 'row/dual code automorphism groups differ')
            result.update(id=i + 1, algebraic_degree=algebraic_degree(table),
                          graph_matrix_rank=int(info['matrix'].rank()),
                          row_code_dimension=int(info['code'].dimension()),
                          dual_code_dimension=int(info['code'].dual_code().dimension()),
                          word_selection=info['selection'],
                          canonical_graph_sha256=info['fingerprint'],
                          canonical_code_matrix=[[int(v) for v in row]
                                                 for row in info['canonical_matrix'].rows()],
                          seconds=time.perf_counter() - then)
            stabilizers.append(result)
            print('n={}, row {}: EA stabilizer {}, code automorphisms {}'.format(
                n, i + 1, result['ea_stabilizer_order'], result['code_automorphism_order']),
                file=sys.stderr, flush=True)
        # These three EA invariants distinguish all supplied representatives.
        signatures = [(a['representative'], s['algebraic_degree'], s['ea_stabilizer_order'])
                      for a, s in zip(assignments, stabilizers)]
        require(len(set(signatures)) == len(tables), 'EA inequivalence needs additional evidence')
        order = ea_group_order(n)
        orbits = []
        for result in stabilizers:
            stabilizer = result['ea_stabilizer_order']
            require(order % stabilizer == 0, 'nonintegral EA orbit size')
            orbits.append(order // stabilizer)
        total = sum(orbits)
        require(total == reported_total, 'sum of computed orbit sizes differs from publication')
        results.append(dict(dimension=n, ccz_representative_ids=[i + 1 for i in representative_indices],
                            ccz_assignments=assignments, ccz_pair_tests=pairs, stabilizers=stabilizers,
                            pairwise_ea_inequivalence_signatures=[list(s) for s in signatures],
                            ea_group_order=order, ea_orbit_sizes=orbits,
                            supplied_ea_orbits_total=total, published_apn_total=reported_total,
                            classification_scope='supplied representatives only; full n=5 EA candidate reduction is pending'))
    names = ['sage/ccz_stabilizers.sage', 'lib/code_classification.py',
             'lib/verify_code_classification.py', 'lib/apn_reference.py',
             'lib/affine_oracle.py', 'lib/ea_equivalence.py', 'lib/affine_refinement.py',
             'data/dimension-four.json', 'data/dimension-five.json']
    record = dict(schema=1, artifact='published-ccz-classes-and-ea-stabilizers', completed=True,
                  finished_utc=datetime.now(timezone.utc).isoformat(),
                  environment=dict(sage=SAGE_VERSION, python=platform.python_version(),
                                   gap=str(libgap.eval('GAPInfo.Version')),
                                   system=platform.system(), machine=platform.machine()),
                  backends=dict(ccz_canonicalization='Bliss colored incidence graphs of invariant spanning codewords',
                                code_automorphisms=['Robert Miller partition refinement', 'Bliss spanning-word graphs'],
                                ea_intersection='Sage/GAP permutation groups'),
                  conventions=dict(graph_column='(1, x LSB-first, s(x) LSB-first)',
                                   code='binary row code; dual witness and automorphism checks also performed',
                                   permutations='zero-based source coordinate to target coordinate',
                                   graph_witness='augmented matrix acts on column (1,x,s(x))',
                                   ea_witness='s(x) = beta(s(alpha(x))) XOR gamma(x); beta linear'),
                  source_sha256={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in names},
                  checks=checks, dimensions=results, elapsed_seconds=time.perf_counter() - start)
    rendered = json.dumps(record, indent=2, sort_keys=True, default=int) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_name(args.output.name + '.tmp')
        temporary.write_text(rendered)
        temporary.replace(args.output)
    else:
        print(rendered, end='')
    print('Completed supplied-table CCZ and EA-stabilizer verification in {:.3f}s'.format(
        record['elapsed_seconds']), file=sys.stderr, flush=True)


if __name__ == '__main__':
    main()
