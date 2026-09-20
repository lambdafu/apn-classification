"""Replay permutation and 2019 catalogue witnesses and arithmetic.

Does not repeat exhaustive searches, negative decisions, or canonicity checks.
"""
import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from affine_equivalence import verify_witness
from apn_reference import is_apn_derivatives
from ea_equivalence import algebraic_degree
from field_functions import power_table
from ea_catalogue import orders
from walsh import absolute_walsh_spectrum
from code_classification import affine_table, verify_graph_witness


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def verify_permutations(record):
    n = record['dimension']
    published = json.loads((ROOT / 'data/permutations-five.json').read_text())
    small = json.loads((ROOT / 'data/dimension-four.json').read_text())
    expected = {3:[small['permutation_n3']], 4:[], 5:published['representatives']}[n]
    rows = record['representatives']
    require(rows == expected, 'representatives differ')
    for table in rows:
        require(sorted(table) == list(range(1 << n)) and is_apn_derivatives(table),
                'invalid APN permutation')
    witnesses = record['witnesses']
    require(len(witnesses) == (10 if n == 5 else 0), 'wrong witness count')
    seen = set()
    for witness in witnesses:
        kind, row = witness['kind'], witness['row']
        require(kind in ('power', 'inverse') and 1 <= row <= 5 and (kind,row) not in seen,
                'invalid or duplicated witness')
        seen.add((kind,row))
        if kind == 'power':
            source = power_table(n, published['power_exponents'][row-1])
            target_row = row
        else:
            source = [rows[row-1].index(x) for x in range(1 << n)]
            target_row = published['inverse_rows'][row-1]
        require(witness['source'] == source and witness['target_row'] == target_row,
                'witness endpoints differ')
        verify_witness(source, rows[target_row-1], (witness['alpha'], witness['beta']))
    if n == 5:
        require([algebraic_degree(t) for t in rows] == published['degrees'], 'degree differs')
    return dict(representatives=len(rows), affine_witnesses=len(witnesses))


def verify_catalogue(record):
    inputs = json.loads((ROOT / 'data/ea-ccz-2019.json').read_text())
    expected_dimensions = inputs['dimensions'][:record['configuration']['max_dimension']]
    require(len(record['dimensions']) == len(expected_dimensions), 'missing dimension')
    witnesses = permutations = count = 0
    for actual, expected in zip(record['dimensions'], expected_dimensions):
        n = expected['dimension']
        require(actual['dimension'] == n and len(actual['rows']) == len(expected['representatives']),
                'incomplete row list')
        total = 0
        canonical = []
        bijective = 0
        for row, given in zip(actual['rows'], expected['representatives']):
            require(row['row'] == given['row'] and row['canonical'] is True, 'invalid canonical row')
            table = given['table']
            sizes = orders(table, row['input_stabilizer'])
            require(all(row[k] == value for k,value in sizes.items()), 'group arithmetic differs')
            require(row['stabilizer_order'] == given['stabilizer'], 'published stabilizer differs')
            degree = max(1, algebraic_degree(table))
            require(row['degree'] == given['degree'] == degree, 'degree differs')
            spectrum = absolute_walsh_spectrum(table)
            require(row['walsh'] == given['walsh'] == [spectrum.get(i,0) for i in range((1<<n)+1)],
                    'Walsh spectrum differs')
            correction = row['permutation_correction']
            require((correction is not None) == given['bijective'], 'bijection flag differs')
            if correction is not None:
                require(affine_table(correction, linear=True) and
                        sorted(a ^ b for a,b in zip(table,correction)) == list(range(1<<n)),
                        'invalid permutation witness')
                bijective += 1
                permutations += 1
            require(row['ccz_row'] == given['ccz_row'], 'CCZ class differs')
            if row['ccz_row'] == row['row']:
                require(row['ccz_witness'] is None and row['ccz_permutation'] is None, 'unexpected witness')
                canonical.append(row['row'])
            else:
                target = expected['representatives'][row['ccz_row']-1]['table']
                verify_graph_witness(table, target, row['ccz_permutation'], row['ccz_witness'])
                witnesses += 1
            total += row['orbit_size']
            count += 1
        require(total == (1<<n)**(1<<n) == actual['orbit_sum'] == actual['all_functions'], 'coverage arithmetic differs')
        require(actual['ea_classes'] == len(actual['rows']) and actual['ccz_classes'] == len(canonical)
                and actual['ccz_representative_rows'] == canonical and actual['bijective_classes'] == bijective,
                'summary counts differ')
        require(actual['distinct_orbit_sizes'] == len({r['orbit_size'] for r in actual['rows']}) and
                actual['distinct_walsh_spectra'] == len({tuple(r['walsh']) for r in actual['rows']}),
                'spectrum/size totals differ')
    return dict(rows=count, ccz_witnesses=witnesses, permutation_witnesses=permutations)


def verify_from_ea(record):
    checks = verify_permutations(record)
    ea = json.loads((ROOT/'data/dimension-five.json').read_text())['representatives']
    require(len(record['ea_classes']) == 7, 'missing EA correction search')
    assigned = {i:[] for i in range(1,8)}
    for item in record['assignments']:
        ea_row = item['ea_row']
        require(ea_row in assigned and 1 <= item['target_row'] <= 5, 'invalid assignment')
        correction = item['correction']
        require(len(correction) == 32 and affine_table(correction,linear=True), 'invalid linear correction')
        source = [a ^ b for a,b in zip(ea[ea_row-1]['table'],correction)]
        require(sorted(source) == list(range(32)) and is_apn_derivatives(source), 'not an APN permutation')
        verify_witness(source,record['representatives'][item['target_row']-1],(item['alpha'],item['beta']))
        assigned[ea_row].append(item)
    for i,row in enumerate(record['ea_classes'],1):
        corrections = [a['correction'] for a in assigned[i]]
        require(row['ea_row'] == i and row['corrections'] == row['work']['corrections'] == len(corrections),
                'correction count differs')
        require(len({tuple(t) for t in corrections}) == len(corrections), 'duplicate correction')
        require(row['affine_rows'] == sorted({a['target_row'] for a in assigned[i]}), 'class assignment differs')
        require(row['correction_tables_sha256'] == hashlib.sha256(b''.join(bytes(t) for t in corrections)).hexdigest(),
                'correction checksum differs')
    require({a['target_row'] for a in record['assignments']} == set(range(1,6)), 'missing affine class')
    checks['correction_assignments'] = len(record['assignments'])
    checks['correction_counts_by_EA_row'] = [r['corrections'] for r in record['ea_classes']]
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    start = time.perf_counter()
    record = json.loads(args.record.read_text())
    require(record['completed'] is True, 'incomplete record')
    for name, digest in record['source_sha256'].items():
        require(hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == digest,
                'source changed: ' + name)
    if record['artifact'] == 'apn-permutations':
        checks = verify_permutations(record)
    elif record['artifact'] == 'ea-ccz-catalogue-2019':
        checks = verify_catalogue(record)
    elif record['artifact'] == 'apn-permutations-from-ea':
        checks = verify_from_ea(record)
    else:
        raise ValueError('unsupported record')
    output = dict(completed=True, artifact=record['artifact']+'-replay',
                  record_sha256=hashlib.sha256(args.record.read_bytes()).hexdigest(),
                  verifier_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  checks=checks, seconds=time.perf_counter()-start,
                  scope='Source hashes, positive witnesses, table properties and arithmetic; exhaustive searches and negative decisions are not repeated.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2)+'\n')
    print(json.dumps(checks))


if __name__ == '__main__':
    main()
