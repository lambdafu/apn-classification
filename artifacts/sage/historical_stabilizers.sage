"""Reconstruct Algorithm 3 and Note 9 using recursive three-template search.

The modern code-group result is read only AFTER generator discovery, as an
independent comparison. It never supplies a generator or a pruning orbit.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import sys
import time

from sage.all import SymmetricGroup
from sage.env import SAGE_VERSION

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from historical_stabilizer import (search, canonical_generators, permutation_group,
                                   stabilizer_orbits, generator_orbits, orbit_filter,
                                   printed_note9_filter)
from ea_equivalence import verify_ea_witness
from compiled import load_kernel
from verify_historical_stabilizer import verify_kernel


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def note9_generators():
    cycles = [
        [(2,17,25,22,28),(3,16,24,23,29),(4,21,12,26,6),
         (5,20,13,27,7),(8,15,10,30,19),(9,14,11,31,18)],
        [(1,2,10,13,4),(3,8,7,9,5),(6,11,15,14,12),
         (16,27,20,26,22),(17,25,30,23,18),(21,24,28,29,31)],
        [(x,x+1) for x in range(0,32,2)]]
    result = []
    for generator in cycles:
        table = list(range(32))
        for cycle in generator:
            for x, y in zip(cycle, cycle[1:] + cycle[:1]):
                table[x] = y
        result.append(tuple(table))
    return result


def verify_sequence(group, generators, q):
    """Enumerate the discovered group to check every min(H minus H_k)."""
    elements = sorted(tuple(int(g(x + 1)) - 1 for x in range(q)) for g in group)
    known = {tuple(range(q))}
    for i in range(len(generators) + 1):
        subgroup = permutation_group(generators[:i], q)
        require(generator_orbits(generators[:i], q) == stabilizer_orbits(subgroup, q),
                'selected-generator orbits differ from full prefix stabilizer orbits')
    for i, alpha in enumerate(generators):
        require(alpha == next(g for g in elements if g not in known),
                'generator is not the lexicographically first missing element')
        subgroup = permutation_group(generators[:i+1], q)
        known = {tuple(int(g(x + 1)) - 1 for x in range(q)) for g in subgroup}
    require(known == set(elements), 'generator sequence does not cover the group')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', action='store_true')
    parser.add_argument('--max-dimension', type=int, choices=(4,5), default=5)
    parser.add_argument('--output', type=Path, default=ROOT/'build/historical-stabilizers.json')
    args = parser.parse_args()
    start = time.perf_counter()
    kernel, build = load_kernel('ea_stabilizer') if not args.reference else (None, None)
    checks = verify_kernel(kernel) if kernel else []
    print('Finite verification completed', flush=True)
    backend = search if args.reference else kernel.search
    four = json.loads((ROOT/'data/dimension-four.json').read_text())
    five = json.loads((ROOT/'data/dimension-five.json').read_text())
    targets = {4: four['ea_representatives'], 5: [r['table'] for r in five['representatives']]}
    cases = []
    computed_groups = {}
    for n in range(4, args.max_dimension + 1):
        for index, table in enumerate(targets[n], 1):
            then = time.perf_counter()

            def progress(step):
                print('n={}, row {}: {} -> {} ({} input nodes)'.format(
                    n, index, step['subgroup_order'], step.get('next_subgroup_order', 'exhausted'),
                    step['work']['input_nodes']), flush=True)

            group, generators, steps = canonical_generators(table, backend, progress)
            seconds = time.perf_counter() - then
            verify_sequence(group, generators, 1 << n)
            computed_groups[n,index] = group
            cases.append(dict(dimension=n, representative=index, order=int(group.order()),
                              steps=steps, canonical_sequence_verified_by_enumeration=True,
                              search_seconds=seconds))
    # Only now consult the independent modern result. Verify its witnesses and
    # compare actual groups, not just orders. Its full-group proof is separate.
    modern_path = ROOT/'results/ccz-stabilizers.json'
    modern = json.loads(modern_path.read_text())
    require(modern['completed'], 'modern comparison record incomplete')
    for dimension in modern['dimensions']:
        n = dimension['dimension']
        if n > args.max_dimension:
            continue
        for row in dimension['stabilizers']:
            table = targets[n][row['id'] - 1]
            gens = []
            for w in row['ea_generators']:
                verify_ea_witness(table, table, (w['alpha'],w['beta'],w['gamma']))
                gens.append(w['alpha'])
            require(computed_groups[n,row['id']] == permutation_group(gens, 1 << n),
                    'historical and modern stabilizer groups differ')
    note = None
    if args.max_dimension == 5:
        published = note9_generators()
        row = next(c for c in cases if c['dimension'] == 5 and c['representative'] == 1)
        discovered = [tuple(step['alpha']) for step in row['steps'] if not step['exhausted']]
        require(discovered == published, 'canonical generators differ from Note 9')
        orbits = generator_orbits(published, 32)
        require(orbits[:3] == [tuple(range(32)), tuple(range(1,32)), (2,17,22,25,28)]
                and all(orbit == (x,) for x,orbit in enumerate(orbits) if x >= 3),
                'Note 9 orbit description differs')
        # Exhaust the shape-relevant assignments for the three rules: a full
        # affine map is sampled below; all its affine prefix closures are used.
        from random import Random
        from affine_refinement import refine, complete
        rng = Random(2008)
        prefix_checks = 0
        for _ in range(256):
            alpha = (None,) * 32
            while None in alpha:
                x = alpha.index(None)
                value = rng.choice([v for v in range(32) if v not in alpha])
                alpha = refine(alpha,x,value,injective=True)
                require(orbit_filter(alpha,orbits) == printed_note9_filter(alpha),
                        'generic generator-orbit filter differs from printed Note 9 rules')
                prefix_checks += 1
        # Concrete EA tests with the published target stabilizer. The first
        # positive deliberately needs a nonidentity alpha and nonzero gamma.
        target = targets[5][0]
        alpha = tuple(x ^ ((x & 1) << 1) for x in range(32))
        require(SymmetricGroup(32)([x + 1 for x in alpha]) not in computed_groups[5,1],
                'positive probe must use an input map outside the target stabilizer')
        source = [target[alpha[x]] ^ x ^ 9 for x in range(32)]
        positive, pw = backend(source, target, orbits)
        require(positive is not None, 'target-stabilizer positive search failed')
        verify_ea_witness(source, target, positive)
        require(tuple(positive[0]) != tuple(range(32)), 'positive probe has trivial input map')
        negative, nw = backend(targets[5][1], target, orbits)
        require(negative is None, 'two known EA-inequivalent quadratics matched')
        note = dict(published_generators_match_exactly=True, order=row['order'], orbits=orbits,
                    selected_generator_indices=[[1,2,3],[1,2],[1]],
                    printed_filter_affine_prefix_checks=prefix_checks,
                    positive=dict(source_table=source, target_table=target,
                                  alpha=list(positive[0]),beta=list(positive[1]),gamma=list(positive[2]),work=pw),
                    negative=dict(source_representative=2,target_representative=1,
                                  equivalent=False,exhausted=True,work=nw))
    names = ['sage/historical_stabilizers.sage','lib/historical_stabilizer.py',
             'lib/verify_historical_stabilizer.py','lib/affine_refinement.py',
             'lib/affine_oracle.py','lib/apn_reference.py','lib/ea_equivalence.py',
             'lib/code_classification.py','data/dimension-four.json','data/dimension-five.json']
    if kernel:
        names += ['lib/compiled.py','cython/ea_stabilizer.pyx']
    result = dict(schema=1, artifact='historical-ea-stabilizer-reconstruction', completed=True,
                  finished_utc=datetime.now(timezone.utc).isoformat(),
                  environment=dict(sage=SAGE_VERSION,python=platform.python_version(),
                                   system=platform.system(),machine=platform.machine()),
                  conventions=dict(equation='target = beta(source(alpha)) XOR gamma',
                                   pruning='right composition by target input self-equivalences',
                                   forced_equation_propagation=not args.reference,
                                   generator_order='lexicographic alpha; incumbent bound resolves interleaved beta guesses'),
                  compiled=build, checks=checks, cases=cases, note9=note,
                  independent_modern_groups_equal=True,
                  modern_record_sha256=hashlib.sha256(modern_path.read_bytes()).hexdigest(),
                  source_sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in names},
                  elapsed_seconds=time.perf_counter()-start)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print('Completed in {:.3f}s'.format(result['elapsed_seconds']),flush=True)


if __name__ == '__main__':
    main()
