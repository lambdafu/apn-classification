"""Finite comparisons for the compiled, mutable affine search."""
from itertools import product, combinations
from affine_refinement import refine
from affine_canonicity import smaller_witness, search_apn


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def verify_kernel(kernel):
    checks = []
    for n in (1, 2):
        q = 1 << n
        # Independent complete affine maps from arbitrary columns and offset.
        maps = []
        for parameters in product(range(q), repeat=n + 1):
            table = []
            for x in range(q):
                y = parameters[0]
                for i in range(n):
                    if (x >> i) & 1: y ^= parameters[i + 1]
                table.append(y)
            maps.append(tuple(table))
        domains = []
        for mask in range(1 << q):
            D = {x for x in range(q) if (mask >> x) & 1}
            if all(a ^ b ^ c in D for a, b, c in product(D, repeat=3)):
                domains.append(D)
        templates = {tuple(table[x] if x in D else None for x in range(q))
                     for D in domains for table in maps}
        transitions = 0
        for table in templates:
            for point, value, injective in product(range(q), range(q), (False, True)):
                expected = refine(table, point, value, injective=injective)
                for poison in (0, q - 1, 255):
                    actual = kernel.refine_table(table, point, value, injective=injective, poison=poison)
                    require(actual == expected, 'masked refinement differs from immutable reference')
                    transitions += 1
        prefixes = 0
        for length in range(q + 1):
            for prefix in product(range(q), repeat=length):
                expected = smaller_witness(prefix, n) is not None
                for poison in (0, q - 1, 255):
                    require(kernel.smaller(prefix, n, poison=poison) == expected,
                            'compiled prefix filter differs from reference')
                    prefixes += 1
        checks.append(dict(check='all_small_templates_and_prefixes', dimension=n,
                           templates=len(templates), transition_poison_cases=transitions,
                           prefix_poison_cases=prefixes))

    # Exercise the largest used mask bit and closure at every supported size.
    for n in (3, 4, 5):
        q = 1 << n
        target = tuple(x ^ (q - 1) for x in range(q))
        partial = (None,) * q
        # Translated affine basis, starting at q-1, does not start at zero.
        for point in [q - 1] + [(q - 1) ^ (1 << i) for i in range(n)]:
            expected = refine(partial, point, target[point], injective=True)
            require(kernel.refine_table(partial, point, target[point], injective=True,
                                        poison=255) == expected, 'high-bit refinement mismatch')
            partial = expected
        require(partial == target, 'translated basis incomplete')
    checks.append(dict(check='high_bit_translated_bases', dimensions=[3, 4, 5]))

    for n, normalized, permutations in [(1, True, False), (2, True, False),
                                        (3, True, False), (4, True, False),
                                        (3, False, True), (4, False, True)]:
        stats = {}
        rows = list(search_apn(n, normalized=normalized, permutations=permutations, stats=stats))
        expected = b''.join(bytes(row) for row in rows)
        for poison in (0, 255):
            data, actual, work = kernel.search(n, normalized=normalized,
                                               permutations=permutations, poison=poison, propagation=False)
            require(data == expected and actual == stats,
                    'compiled search differs in tables or depth profile')
        checks.append(dict(check='complete_search_comparison', dimension=n,
                           normalized=normalized, permutations=permutations,
                           candidates=len(rows), poison_values=[0, 255]))
    # Final candidates must be invariant under deferred checking. Leaf-only
    # tests are cheap in n<=3; use practical cutoffs in the full n=4 search.
    for n, cutoffs in [(2, range(1, 5)), (3, range(1, 9)), (4, (11, 12, 15, 16))]:
        q = 1 << n
        expected = b''.join(bytes(row) for row in search_apn(n, normalized=True))
        for cutoff in cutoffs:
            data, stats, work = kernel.search(n, cutoff=cutoff, poison=255, propagation=False)
            require(data == expected, 'cutoff changes the final candidate set')
            for i, (tested, skipped) in enumerate(zip(work['affine_checks_by_depth'],
                                                     work['affine_skips_by_depth'])):
                require(tested + skipped == stats['attempted'][i] - stats['apn_rejected'][i],
                        'affine scheduling counters do not cover APN-passing attempts')
                if cutoff <= i + 1 < q:
                    require(tested == 0, 'affine filter ran inside the skipped interval')
                else:
                    require(skipped == 0, 'affine filter skipped a required depth')
            require(work['apn_completions'] == work['affine_checks_by_depth'][-1],
                    'a completed APN function escaped affine checking')
            require(work['apn_completions'] - stats['affine_rejected'][-1] == len(data) // q,
                    'leaf filtering counts do not match emitted candidates')
            checks.append(dict(check='cutoff_candidate_invariance', dimension=n, cutoff=cutoff,
                candidates=len(data) // q, apn_completions=work['apn_completions'],
                affine_checks_by_depth=work['affine_checks_by_depth'],
                affine_skips_by_depth=work['affine_skips_by_depth']))
    for bad in (0, -1, 17, 1.5, True):
        try:
            kernel.search(4, cutoff=bad)
        except ValueError:
            continue
        raise RuntimeError('invalid cutoff accepted')
    return checks
