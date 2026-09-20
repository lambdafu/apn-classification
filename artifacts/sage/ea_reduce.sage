"""Certify the saved candidate set's reduction to proposed EA representatives.

Uses exact EA backtracking and checked maps, not CCZ or stabilizer signatures.
Proposed representatives are inputs to be validated, never assumed complete.
"""
import argparse
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import multiprocessing
from pathlib import Path
import platform
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'lib'))
from apn_reference import is_apn_derivatives
from ea_equivalence import algebraic_degree, verify_ea_witness
from compiled import load_kernel
from verify_ea_reduction import verify_kernel


def invariant(table):
    # D_a(s)(x) = s(x+a)+s(x). Affine input changes permute nonzero a;
    # output GL and constant derivative corrections preserve these degrees.
    histogram=Counter(algebraic_degree(tuple(table[x]^table[x^a] for x in range(len(table))))
                      for a in range(1,len(table)))
    return algebraic_degree(table),tuple(sorted(histogram.items()))


def initialize(module_name,module_file,representatives):
    global KERNEL,TARGETS,SIGNATURES
    spec=importlib.util.spec_from_file_location(module_name,module_file)
    KERNEL=importlib.util.module_from_spec(spec);spec.loader.exec_module(KERNEL)
    TARGETS=representatives
    SIGNATURES=[invariant(t) for t in TARGETS]


def assign(task):
    index,table=task
    signature=invariant(table)
    nodes=0;tests=[]
    for j,target in enumerate(TARGETS):
        if signature!=SIGNATURES[j]:
            tests.append(dict(target=j+1,equivalent=False,method='degree/derivative-degree invariant'))
            continue
        witness,work=KERNEL.witness(table,target)
        nodes+=work
        tests.append(dict(target=j+1,equivalent=witness is not None,method='exact EA backtracking',nodes=work))
        if witness is not None:
            verify_ea_witness(table,target,witness)
            return dict(candidate=index,representative=j+1,alpha=list(witness[0]),beta=list(witness[1]),
                        gamma=list(witness[2]),invariant=signature,nodes=nodes,tests=tests)
    raise RuntimeError('Unmatched candidate {}; proposed representatives do not establish coverage'.format(index))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workers',type=int,default=1)
    parser.add_argument('--output',type=Path,default=ROOT/'build/ea-reduction-5.json')
    args=parser.parse_args()
    if not 1<=args.workers<=32:parser.error('workers must be 1..32')
    input_path=ROOT/'results/dimension-5-weak-ea-candidates.txt'
    search_path=ROOT/'results/ea-candidates-5.json'
    proposals_path=ROOT/'data/dimension-five.json'
    search=json.loads(search_path.read_text());proposals=json.loads(proposals_path.read_text())
    data=input_path.read_bytes()
    assert search['completed'] and hashlib.sha256(data).hexdigest()==search['outputs']['candidate_tables']['sha256']
    tables=[tuple(map(int,line.split())) for line in data.decode().splitlines() if line and not line.startswith('#')]
    assert tables==sorted(set(tables)) and len(tables)==search['count']['computed']==11768
    assert all(len(t)==32 and is_apn_derivatives(t) for t in tables)
    assert hashlib.sha256(bytes(y for t in tables for y in t)).hexdigest()==search['tables_sha256']
    targets=[tuple(r['table']) for r in proposals['representatives']]
    assert targets==sorted(set(targets)) and all(t in tables for t in targets)
    kernel,build=load_kernel('ea_reduce')
    checks=verify_kernel(kernel)
    print('Kernel checks passed; testing all 21 proposed representative pairs',flush=True)
    pairs=[]
    for i,source in enumerate(targets):
        for j in range(i+1,len(targets)):
            # All pairs run the exact test, without relying on invariants.
            witness,nodes=kernel.witness(source,targets[j])
            assert witness is None,('proposed representatives are equivalent',i+1,j+1)
            pairs.append(dict(source=i+1,target=j+1,equivalent=False,nodes=nodes,method='exact EA backtracking'))
    print('21 exact negative tests completed; reducing {} candidates with {} workers'.format(len(tables),args.workers),flush=True)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    assignments_path=args.output.with_name('ea-reduction-5-assignments.jsonl')
    # Never replace a completed output while beginning a new run. Progress
    # goes to .partial; the final record is written only after full checking.
    partial=assignments_path.with_suffix(assignments_path.suffix+'.partial')
    started=time.monotonic();last=started
    counts=Counter();first={}
    with partial.open('w') as stream, ProcessPoolExecutor(max_workers=args.workers,
            mp_context=multiprocessing.get_context('spawn'),initializer=initialize,
            initargs=(kernel.__name__,kernel.__file__,targets)) as pool:
        for row in pool.map(assign,enumerate(tables,1),chunksize=8):
            verify_ea_witness(tables[row['candidate']-1],targets[row['representative']-1],
                              (row['alpha'],row['beta'],row['gamma']))
            counts[row['representative']]+=1
            first.setdefault(row['representative'],row['candidate'])
            stream.write(json.dumps(row,separators=(',',':'))+'\n')
            if time.monotonic()-last>=10:
                stream.flush();last=time.monotonic()
                print('{} / {} checked; {:.1f}s; class counts {}'.format(row['candidate'],len(tables),last-started,dict(sorted(counts.items()))),flush=True)
    assert sum(counts.values())==len(tables) and len(counts)==7
    assert [tables[first[i+1]-1] for i in range(7)]==targets
    partial.replace(assignments_path)
    names=['sage/ea_reduce.sage','cython/ea_reduce.pyx','lib/ea_equivalence.py','lib/affine_refinement.py',
           'lib/apn_reference.py','lib/compiled.py','lib/verify_ea_reduction.py','lib/affine_oracle.py']
    result=dict(schema=1,artifact='dimension-five-complete-EA-candidate-reduction',completed=True,
        finished_utc=datetime.now(timezone.utc).isoformat(),workers=args.workers,seconds=time.monotonic()-started,
        environment=dict(python=platform.python_version(),system=platform.system(),machine=platform.machine()),
        build=build,source_sha256={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in names},
        inputs={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (input_path,search_path,proposals_path)},
        checks=checks,candidates=len(tables),ea_classes=7,representatives=[list(t) for t in targets],
        class_counts=[counts[i+1] for i in range(7)],first_candidate_indices=[first[i+1] for i in range(7)],
        representative_pair_tests=pairs,outputs=dict(assignments=dict(filename=assignments_path.name,
            sha256=hashlib.sha256(assignments_path.read_bytes()).hexdigest(),count=len(tables))),
        conventions=dict(candidate_indices='one-based lexicographic input rows',representatives='article Table 3 IDs 1..7',
            witness='target(x)=beta(source(alpha(x))) XOR gamma(x); beta linear'),
        scope='All saved candidates assigned with checked EA witnesses; all proposed representative pairs tested exactly inequivalent; each proposed representative is first in its input class.',
        adaptation='Gamma eliminated by affine interpolation; source degree <=2 allows alpha(0)=0. Derivative-degree histogram is an additional documented scheduling invariant; no code/stabilizer classifier used.')
    temp=args.output.with_suffix(args.output.suffix+'.tmp');temp.write_text(json.dumps(result,indent=2)+'\n');temp.replace(args.output)
    print('Completed:',args.output,'counts',result['class_counts'],flush=True)


if __name__=='__main__':main()
