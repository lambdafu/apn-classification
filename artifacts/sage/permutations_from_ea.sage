"""Complete n=5 affine permutation classification using verified EA coverage."""
import argparse
import hashlib
import json
import platform
import sys
import time
from datetime import datetime, timezone
from itertools import product
from pathlib import Path
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from compiled import load_kernel
from permutation_corrections import all_corrections
from affine_equivalence import equivalence_witness, verify_witness
from affine_canonicity import smaller_witness
from apn_reference import is_apn_derivatives
from ea_equivalence import algebraic_degree
from field_functions import power_table


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', action='store_true', help='brute-force all linear corrections in Python (slow)')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    start = time.perf_counter()
    published = json.loads((ROOT/'data/permutations-five.json').read_text())
    ea = json.loads((ROOT/'data/dimension-five.json').read_text())
    reduction_path = ROOT/'results/ea-reduction-5.json'
    reduction = json.loads(reduction_path.read_text())
    replay = json.loads((ROOT/'results/ea-reduction-5-verification.json').read_text())
    require(reduction['completed'] and reduction['ea_classes'] == 7 and
            reduction['representatives'] == [r['table'] for r in ea['representatives']] and
            replay['completed'] and replay['verified_assignments'] == 11768 and
            replay['record_sha256'] == hashlib.sha256(reduction_path.read_bytes()).hexdigest(),
            'missing completed EA coverage evidence')
    kernel, build = (None,None) if args.reference else load_kernel('permutation_corrections')
    affine, affine_build = (None,None) if args.reference else load_kernel('affine_search')
    checks = []
    if kernel:
        # All n<=2 functions, plus all seven n=3 EA representatives.
        cases = [tuple(t) for n in (1,2) for t in product(range(1<<n), repeat=1<<n)]
        catalogue = json.loads((ROOT/'data/ea-ccz-2019.json').read_text())
        cases += [tuple(r['table']) for r in catalogue['dimensions'][2]['representatives']]
        for table in cases:
            expected = b''.join(bytes(t) for t in all_corrections(table))
            actual, work = kernel.search(table)
            require(actual == expected and work['corrections'] == len(expected)//len(table),
                    'linear correction search differs from exhaustive reference')
        checks.append(dict(check='all_small_functions_and_n3_EA_representatives', cases=len(cases)))
    rows = published['representatives']
    for i,table in enumerate(rows):
        require(is_apn_derivatives(table) and sorted(table) == list(range(32)), 'not an APN permutation')
        require(algebraic_degree(table) == published['degrees'][i], 'degree differs')
        smaller = affine.smaller(table,5) if affine else smaller_witness(table,5) is not None
        require(not smaller, 'published permutation is not affine canonical')
    checks.append(dict(check='exact_complete_affine_canonicity', representatives=5))
    assignments, classes = [], []
    for ea_row, entry in enumerate(ea['representatives'],1):
        table = entry['table']
        then = time.perf_counter()
        if kernel:
            raw, work = kernel.search(table)
            corrections = [list(raw[i:i+32]) for i in range(0,len(raw),32)]
            require(len(raw) % 32 == 0 and len(corrections) == work['corrections'], 'truncated corrections')
        else:
            corrections = list(map(list,all_corrections(table)))
            work = dict(corrections=len(corrections))
        require(len({tuple(t) for t in corrections}) == len(corrections), 'duplicate correction')
        class_rows = set()
        for correction in corrections:
            source = [a ^ b for a,b in zip(table,correction)]
            require(sorted(source) == list(range(32)) and is_apn_derivatives(source), 'invalid correction')
            degree = algebraic_degree(source)
            witness = None
            # Reuse successful target ordering, but do not assume every
            # correction from an EA class belongs to one affine class.
            order = sorted(class_rows) + [i for i in range(1,6) if i not in class_rows]
            for target_row in order:
                if degree != published['degrees'][target_row-1]:
                    continue
                witness = equivalence_witness(source, rows[target_row-1])
                if witness is not None:
                    break
            require(witness is not None, 'a permutation has no published affine class')
            verify_witness(source,rows[target_row-1],witness)
            class_rows.add(target_row)
            assignments.append(dict(ea_row=ea_row, correction=correction,
                                    target_row=target_row, alpha=witness[0], beta=witness[1]))
        classes.append(dict(ea_row=ea_row, corrections=len(corrections),
                            affine_rows=sorted(class_rows), work=work,
                            correction_tables_sha256=hashlib.sha256(b''.join(bytes(t) for t in corrections)).hexdigest(),
                            seconds=time.perf_counter()-then))
        print('EA row {}: {} corrections, affine rows {}'.format(ea_row,len(corrections),sorted(class_rows)),
              file=sys.stderr,flush=True)
    require({r['target_row'] for r in assignments} == set(range(1,6)), 'not all affine classes covered')
    witnesses = []
    for i,table in enumerate(rows):
        for kind,source in [('power',power_table(5,published['power_exponents'][i])),
                            ('inverse',[table.index(x) for x in range(32)])]:
            target_row = i+1 if kind == 'power' else published['inverse_rows'][i]
            witness = equivalence_witness(source,rows[target_row-1])
            verify_witness(source,rows[target_row-1],witness)
            witnesses.append(dict(kind=kind,row=i+1,target_row=target_row,source=source,
                                  alpha=witness[0],beta=witness[1]))
    sources = ['sage/permutations_from_ea.sage','lib/permutation_corrections.py',
               'cython/permutation_corrections.pyx','lib/affine_equivalence.py','lib/affine_canonicity.py',
               'lib/affine_refinement.py','lib/apn_reference.py','lib/ea_equivalence.py',
               'lib/field_functions.py','lib/compiled.py','cython/affine_search.pyx',
               'data/permutations-five.json','data/dimension-five.json','data/ea-ccz-2019.json',
               'results/ea-reduction-5.json','results/ea-reduction-5-verification.json',
               'results/ea-candidates-5.json','results/dimension-5-weak-ea-candidates.txt']
    result = dict(schema=1,artifact='apn-permutations-from-ea',completed=True,dimension=5,
                  finished_utc=datetime.now(timezone.utc).isoformat(),
                  environment=dict(sage=SAGE_VERSION,python=platform.python_version(),
                                   system=platform.system(),machine=platform.machine()),
                  source_sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},
                  configuration=dict(reference=args.reference,method='all linear corrections of seven exhaustively classified EA representatives'),
                  build=build,affine_build=affine_build,checks=checks,
                  representatives=rows,ea_classes=classes,assignments=assignments,witnesses=witnesses,
                  elapsed_seconds=time.perf_counter()-start,
                  scope='Complete affine permutation classification using retained EA coverage; does not claim a fresh full APN permutation-tree traversal.')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    temporary=args.output.with_suffix('.tmp')
    temporary.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    temporary.replace(args.output)


if __name__ == '__main__':
    main()
