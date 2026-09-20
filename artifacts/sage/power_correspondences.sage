"""Certify the n=4,5 power functions and the article's trace-family instances.

Generate with Sage; replay with ordinary Python using --verify-record FILE.
The optional --reference uses the readable EA search instead of Cython.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from apn_reference import is_apn_derivatives, is_apn_planes
from ea_equivalence import (algebraic_degree, normalized_equivalence_witness,
                            verify_ea_witness)
from field_functions import MODULI, multiply, power_table, family_table


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def inputs():
    four = json.loads((ROOT / 'data/dimension-four.json').read_text())
    five = json.loads((ROOT / 'data/dimension-five.json').read_text())
    return {4: four['ea_representatives'],
            5: [r['table'] for r in five['representatives']]}, five


def verify(record):
    """Rebuild every source table and check each map without an EA search."""
    tables, five = inputs()
    require(record['completed'], 'record is incomplete')
    for name in ('data/dimension-four.json', 'data/dimension-five.json'):
        require(hashlib.sha256((ROOT / name).read_bytes()).hexdigest() ==
                record['source_sha256'][name], 'published input hash differs')
    require([case['dimension'] for case in record['dimensions']] == [4, 5],
            'expected dimensions four and five')
    checked = 0
    for case in record['dimensions']:
        n = case['dimension']
        require(case['modulus_bits'] == MODULI[n], 'field convention differs')
        powers = {d: power_table(n, d) for d in range(1, 1 << n)}
        apn = [d for d, table in powers.items() if is_apn_derivatives(table)]
        require(apn == case['apn_power_exponents'], 'power exhaustion differs')
        require([r['exponent'] for r in case['powers']] == apn,
                'power assignments must cover each APN exponent exactly once')
        require([r['i'] for r in case['families']] == ([1] if n == 4 else [1, 2]),
                'missing or duplicate family instance')
        for kind in ('powers', 'families'):
            for row in case[kind]:
                source = (powers[row['exponent']] if kind == 'powers'
                          else family_table(n, row['i']))
                require(source == row['source_table'], 'source table differs')
                require(is_apn_derivatives(source) and is_apn_planes(source),
                        'source is not APN')
                require(1 <= row['representative'] <= len(tables[n]), 'invalid target')
                target = tables[n][row['representative'] - 1]
                require(target == row['target_table'], 'published target differs')
                verify_ea_witness(source, target, (row['alpha'], row['beta'], row['gamma']))
                checked += 1
        assignments = {r['exponent']: r['representative'] for r in case['powers']}
        expected = ({3: 1} if n == 4 else
                    {r['reported_ea_power_exponent']: r['id']
                     for r in five['representatives'] if r['reported_ea_power_exponent']})
        require(all(assignments.get(d) == r for d, r in expected.items()),
                'published power correspondence differs')
        require(set(assignments.values()) == ({1} if n == 4 else {1, 2, 5, 6, 7}),
                'power classes differ')
        require({r['representative'] for r in case['families']} ==
                ({2} if n == 4 else {3, 4}), 'family classes differ')
    return dict(checked_witnesses=checked, source_tables_rebuilt=True,
                all_positive_exponents_exhausted=True,
                negative_EA_tests_reexecuted=False,
                note='Nonpower conclusions additionally use the separately recorded pairwise EA inequivalence.')


def generate(reference):
    from sage.all import GF, PolynomialRing
    from sage.env import SAGE_VERSION
    tables, _ = inputs()
    build = None
    if not reference:
        from compiled import load_kernel
        kernel, build = load_kernel('ea_reduce')
    started = time.perf_counter()
    cases = []
    for n in (4, 5):
        q = 1 << n
        ring = PolynomialRing(GF(2), 'z')
        z = ring.gen()
        modulus = sum(((MODULI[n] >> i) & 1) * z**i for i in range(n + 1))
        require(modulus.is_irreducible(), 'chosen modulus is reducible')
        field = GF(q, name='a', modulus=modulus)
        elements = [sum(((x >> i) & 1) * field.gen()**i for i in range(n))
                    for x in range(q)]

        def encode(value):
            return sum(int(c) << i for i, c in enumerate(value.polynomial().list()))

        # Check all products, not just those appearing in the published maps.
        require(all(encode(elements[x] * elements[y]) == multiply(x, y, n)
                    for x in range(q) for y in range(q)), 'field implementations differ')

        def assign(source):
            before = time.perf_counter()
            for j, target in enumerate(tables[n], 1):
                if algebraic_degree(source) != algebraic_degree(target):
                    continue
                witness = (normalized_equivalence_witness(source, target) if reference
                           else kernel.witness(source, target)[0])
                if witness is None:
                    continue
                verify_ea_witness(source, target, witness)
                return dict(representative=j, source_table=source, target_table=target,
                            alpha=list(witness[0]), beta=list(witness[1]), gamma=list(witness[2]),
                            elapsed_seconds=time.perf_counter() - before)
            raise RuntimeError('unmatched field function')

        case = dict(dimension=n, modulus_bits=MODULI[n], modulus=str(modulus),
                    apn_power_exponents=[], powers=[], families=[], checked_field_products=q*q)
        for d in range(1, q):
            source = [encode(x**d) for x in elements]
            require(source == power_table(n, d), 'power implementations differ')
            apn = is_apn_derivatives(source)
            require(apn == is_apn_planes(source), 'APN predicates differ')
            if apn:
                case['apn_power_exponents'].append(d)
                row = assign(source)
                row['exponent'] = d
                case['powers'].append(row)
                print('n={}, x^{} -> EA row {}'.format(n, d, row['representative']), flush=True)
        for i in ([1] if n == 4 else [1, 2]):
            source = []
            for x in elements:
                gold = x**((1 << i) + 1)
                factor = x**(1 << i) + x + (field.one() if n == 4 else field.zero())
                argument = gold + (x if n == 5 else field.zero())
                source.append(encode(gold + factor * argument.trace()))
            require(source == family_table(n, i), 'family implementations differ')
            row = assign(source)
            row.update(i=i, article_equation=5 if n == 4 else 6)
            case['families'].append(row)
            print('n={}, trace family i={} -> EA row {}'.format(n, i, row['representative']), flush=True)
        if n == 4:
            for row in case['powers'] + case['families']:
                witness = normalized_equivalence_witness(row['source_table'], row['target_table'])
                require(witness is not None, 'readable n=4 search found no witness')
                verify_ea_witness(row['source_table'], row['target_table'], witness)
            case['readable_reference_correspondences_checked'] = 5
        cases.append(case)
    names = ['sage/power_correspondences.sage', 'lib/field_functions.py',
             'lib/apn_reference.py', 'lib/ea_equivalence.py', 'lib/affine_refinement.py',
             'data/dimension-four.json', 'data/dimension-five.json']
    if build:
        names += ['lib/compiled.py', 'cython/ea_reduce.pyx']
    record = dict(schema=1, artifact='power-and-trace-family-correspondences', completed=True,
                  finished_utc=datetime.now(timezone.utc).isoformat(),
                  environment=dict(sage=SAGE_VERSION, python=platform.python_version(),
                                   system=platform.system(), machine=platform.machine()),
                  search='readable normalized EA' if reference else 'Cython normalized EA',
                  compiled=build, dimensions=cases,
                  source_sha256={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in names},
                  elapsed_seconds=time.perf_counter() - started)
    record['verification'] = verify(record)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', action='store_true')
    parser.add_argument('--verify-record', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.verify_record:
        record = dict(artifact='power-correspondences-certificate-replay', completed=True,
                      finished_utc=datetime.now(timezone.utc).isoformat(),
                      environment=dict(python=platform.python_version(),
                                       system=platform.system(), machine=platform.machine()),
                      record_sha256=hashlib.sha256(args.verify_record.read_bytes()).hexdigest(),
                      source_sha256={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
                                     for p in ('sage/power_correspondences.sage',
                                               'lib/field_functions.py', 'lib/ea_equivalence.py',
                                               'lib/apn_reference.py', 'lib/affine_refinement.py')},
                      verification=verify(json.loads(args.verify_record.read_text())))
    else:
        record = generate(args.reference)
    rendered = json.dumps(record, indent=2, sort_keys=True) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    else:
        print(rendered, end='')


if __name__ == '__main__':
    main()
