"""Check the seven published dimension-five inputs, without classification.

Runs under Sage or ordinary Python; this is a small deterministic verification.
Published equivalences and stabilizer orders are targets, not checked here.
"""
import argparse
import hashlib
import json
import platform
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from apn_reference import is_apn_derivatives, is_apn_planes
from ea_equivalence import algebraic_degree
from walsh import absolute_walsh_spectrum, algebraic_degree_by_subsets


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def pairs(counter):
    return [[value, count] for value, count in sorted(counter.items())]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    started = time.perf_counter()
    inputs = json.loads((ROOT / 'data/dimension-five.json').read_text())
    q = int(1 << inputs['dimension'])
    rows = inputs['representatives']
    require([r['id'] for r in rows] == list(range(1, 8)), 'unexpected representative identifiers')
    tables = [tuple(row['table']) for row in rows]
    require(tables == sorted(set(tables)), 'published tables must be distinct and ordered')
    # The zero table supplies a simple analytic check on the conventions.
    for nonzero in (False, True):
        masks = q - 1 if nonzero else q
        expected_zero = Counter({0: masks * (q - 1), q: masks})
        for method in ('direct', 'fast'):
            require(absolute_walsh_spectrum([0] * q, nonzero_output=nonzero,
                                            method=method) == expected_zero,
                    'zero-function Walsh check fails')
    records = []
    for row in rows:
        table = row['table']
        require(len(table) == q, 'incorrect table length')
        require(all(table[p] == 0 for p in [0, 1, 2, 4, 8, 16]), 'basis normalization fails')
        require(is_apn_derivatives(table) and is_apn_planes(table), 'published input is not APN')
        degree = algebraic_degree(table)
        require(degree == algebraic_degree_by_subsets(table) == row['reported_algebraic_degree'],
                'algebraic-degree check fails')
        full = absolute_walsh_spectrum(table, nonzero_output=False)
        restricted = absolute_walsh_spectrum(table, nonzero_output=True)
        require(full == absolute_walsh_spectrum(table, nonzero_output=False, method='direct'),
                'direct and fast Walsh transforms disagree')
        require(restricted == absolute_walsh_spectrum(table, nonzero_output=True, method='direct'),
                'nonzero-output Walsh transforms disagree')
        require(sum(full.values()) == q * q and sum(restricted.values()) == q * (q - 1),
                'Walsh coefficient count fails')
        require(full == restricted + Counter({0: q - 1, q: 1}),
                'zero-output-mask contribution fails')
        key = 'degree_4' if degree == 4 else 'degree_2_or_3'
        reported = inputs['reported_absolute_walsh_spectra'][key]
        require(pairs(full) == reported, 'published Walsh multiplicities do not match full spectrum')
        records.append(dict(id=row['id'], apn_derivatives=True, apn_planes=True,
                            normalized=True, algebraic_degree=degree,
                            absolute_walsh_all_output_masks=pairs(full),
                            absolute_walsh_nonzero_output_masks=pairs(restricted),
                            matches_printed_multiplicities=True))
    sources = ['sage/dimension_five_inputs.sage', 'data/dimension-five.json',
               'lib/walsh.py', 'lib/apn_reference.py', 'lib/ea_equivalence.py',
               'lib/affine_refinement.py']
    record = dict(schema=1, artifact='dimension-five-published-inputs', completed=True,
                  scope='APN, normalization, degree, and Walsh spectra of supplied tables only; no classification or equivalence search',
                  finished_utc=datetime.now(timezone.utc).isoformat(),
                  environment=dict(python=platform.python_version(), system=platform.system(),
                                   machine=platform.machine()),
                  source_sha256={name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                 for name in sources},
                  representatives=records,
                  spectrum_convention_discrepancy=dict(
                      source='Article section 5, printed page 280',
                      defined_output_masks='b != 0', printed_coefficient_count=1024,
                      defined_coefficient_count=992, printed_counts_include_zero_output_mask=True),
                  elapsed_seconds=time.perf_counter() - started)
    rendered = json.dumps(record, indent=2, sort_keys=True, default=int) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    else:
        print(rendered, end='')
    print('Seven published n=5 inputs verified: APN, normalization, degree, and both Walsh conventions ({:.3f}s).'.format(
        record['elapsed_seconds']), file=sys.stderr)


if __name__ == '__main__':
    main()
