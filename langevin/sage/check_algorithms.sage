"""Finite exhaustive and independent checks for the extension algorithms."""
import hashlib
import json
import random
import sys
import time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'lib'))
from components import *
from compiled import load_kernel
from code_equivalence import canonical

start = time.monotonic()
kernel, build = load_kernel()
checks = dict(walsh_cases=0, two_component_cases=0, last_component_cases=0,
              code_invariance_cases=0)
for n in (2,3):
    _, free = quotient([],n)
    for index in range(1 << len(free)):
        words = [] if n==2 else [unpack(index,free)]
        expected = complete_two(words,n)
        actual, _ = kernel.feasible_two(words,n)
        # Exhaust every pair of normalized truth tables, independently of CSP.
        _, positions = quotient(words,n)
        completions = [unpack(i,positions) for i in range(1 << len(positions))]
        brute = any(not unresolved(words+[a,b],n) for a in completions for b in completions)
        assert (expected is not None) == (actual is not None) == brute
        if actual is not None:
            assert not unresolved(words+actual,n)
        checks['two_component_cases'] += 1
        if n==2:
            break
for n in (2,3):
    _, free=quotient([],n)
    cases=[[]]+[[unpack(i,free)] for i in range(1 << len(free))]
    for words in cases:
        expected=list(good_extensions(words,n))
        actual=kernel.enumerate_extensions(words,n,capacity=False)['words']
        assert expected==actual
        assert kernel.enumerate_extensions(words,n)['words']==[w for w in expected if capacity_ok(words+[w],n)]
        checks['walsh_cases']+=1
    for a in range(1 << len(free)):
        parent=[unpack(a,free)]
        _, free2=quotient(parent,n)
        for b in range(1 << len(free2)):
            words=parent+[unpack(b,free2)]
            _, free3=quotient(words,n)
            brute=[unpack(c,free3) for c in range(1 << len(free3))
                   if not unresolved(words+[unpack(c,free3)],n)]
            assert sorted(last_components(words,n))==brute
            checks['last_component_cases']+=1
# Independent immutable search on n=4 partial functions, with fixed random seed.
rng=random.Random(201107)
for _ in range(16):
    words=[rng.getrandbits(16),rng.getrandbits(16)]
    expected=complete_two(words,4)
    actual,_=kernel.feasible_two(words,4)
    assert (expected is None)==(actual is None)
    if actual is not None:
        assert not unresolved(words+actual,4)
    checks['two_component_cases']+=1
# Input-affine and output-component basis/affine changes preserve code keys.
for _ in range(20):
    n=3
    words=[rng.getrandbits(8),rng.getrandbits(8)]
    shift=rng.randrange(8)
    p=[(x ^ (((x>>1)&1)<<2)) ^ shift for x in range(8)]
    affine=span(affine_words(n))
    changed=[transform(words[0]^words[1],p)^rng.choice(affine),
             transform(words[1],p)^rng.choice(affine)]
    assert canonical(words,n)['key']==canonical(changed,n)['key']
    checks['code_invariance_cases']+=1
output=dict(completed=True,checks=checks,seconds=time.monotonic()-start,build=build,
            sources={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in [Path(__file__).resolve()]+list((ROOT/'lib').glob('*.py'))+[ROOT/'cython/extensions.pyx']})
path=ROOT/'build/algorithm-checks.json'
path.parent.mkdir(parents=True,exist_ok=True)
path.write_text(json.dumps(output,indent=2)+'\n')
print(json.dumps(checks),flush=True)
