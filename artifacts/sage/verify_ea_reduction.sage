"""Replay all EA assignment certificates using plain integer operations.

This verifies positive witnesses and file integrity. Exact negative tests are
recorded by ea_reduce.sage; rerun that experiment to repeat those searches.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'lib'))
from apn_reference import is_apn_derivatives
from ea_equivalence import verify_ea_witness


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--record',type=Path,default=ROOT/'results/ea-reduction-5.json')
    p.add_argument('--output',type=Path)
    args=p.parse_args();started=time.monotonic()
    record=json.loads(args.record.read_text())
    assert record['completed']
    for name,digest in record['inputs'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
    source=ROOT/'results/dimension-5-weak-ea-candidates.txt'
    tables=[tuple(map(int,l.split())) for l in source.read_text().splitlines() if l and not l.startswith('#')]
    targets=record['representatives']
    assert len(tables)==record['candidates']==11768
    assert all(is_apn_derivatives(t) for t in targets)
    assignment=record['outputs']['assignments']
    path=args.record.parent/assignment['filename']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==assignment['sha256']
    counts=Counter();first={};total=0
    with path.open() as stream:
        for expected,line in enumerate(stream,1):
            row=json.loads(line)
            assert row['candidate']==expected
            j=row['representative']
            assert type(j) is int and 1<=j<=len(targets)
            verify_ea_witness(tables[expected-1],targets[j-1],(row['alpha'],row['beta'],row['gamma']))
            counts[j]+=1;first.setdefault(j,expected);total+=1
    assert total==len(tables)==assignment['count']
    assert [counts[i+1] for i in range(7)]==record['class_counts']
    assert [first[i+1] for i in range(7)]==record['first_candidate_indices']
    assert [list(tables[first[i+1]-1]) for i in range(7)]==targets
    pairs=record['representative_pair_tests']
    assert len(pairs)==21 and {(r['source'],r['target']) for r in pairs}=={(i,j) for i in range(1,8) for j in range(i+1,8)}
    assert all(r['equivalent'] is False and r['method']=='exact EA backtracking' for r in pairs)
    result=dict(completed=True,verified_assignments=total,class_counts=record['class_counts'],
                all_first_candidates_equal_proposed_representatives=True,
                record_sha256=hashlib.sha256(args.record.read_bytes()).hexdigest(),
                assignments_sha256=assignment['sha256'],seconds=time.monotonic()-started,
                scope='Independent pointwise positive-certificate replay; exact negative search results checked for presence, not recomputed.',
                source_sha256={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in
                    ['sage/verify_ea_reduction.sage','lib/ea_equivalence.py','lib/affine_refinement.py','lib/apn_reference.py']})
    rendered=json.dumps(result,indent=2)+'\n'
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(rendered)
    print(rendered,end='')


if __name__=='__main__':main()
