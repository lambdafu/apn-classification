"""Independent finite checks for sparse APN propagation and affine filtering."""
from itertools import product
from random import Random
from apn_reference import is_apn_derivatives
from apn_propagation import available_values, close_template, search_propagated
from affine_canonicity import search_apn, smaller_witness
from affine_oracle import (affine_permutations, exhaustive_smaller,
                           comparable_smaller, output_minimum_smaller)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def verify_propagation(kernel):
    checks = []

    def check_closure(table, normalized=False, permutations=False):
        expected = close_template(table, normalized=normalized, permutations=permutations)
        for poison in (0, 255):
            actual = kernel.propagate(table, normalized=normalized,
                                      permutations=permutations, poison=poison)
            if expected is None:
                require(actual is None, 'compiled closure misses a contradiction')
            else:
                require(actual is not None and actual[0] == expected,
                        'compiled singleton closure differs from plane reference')
                domains = available_values(expected, normalized=normalized, permutations=permutations)
                masks = tuple(None if v is not None else sum(1 << y for y in domains[p])
                              for p, v in enumerate(expected))
                require(actual[1] == masks, 'incremental exclusion mask differs from all-plane oracle')
        return expected

    for n in (1, 2):
        q = 1 << n
        group = tuple(affine_permutations(n))
        full_apn = [t for t in product(range(q), repeat=q) if is_apn_derivatives(t)]
        count = rejected = 0
        for table in product([None] + list(range(q)), repeat=q):
            for normalized, permutations in ((False, False), (True, False), (False, True)):
                closed = check_closure(table, normalized, permutations)
                compatible = [s for s in full_apn
                              if all(v is None or s[p] == v for p, v in enumerate(table))
                              and (not normalized or all(s[p] == 0 for p in [0] + [1 << i for i in range(n)]))
                              and (not permutations or len(set(s)) == q)]
                require(closed is not None or not compatible,
                        'propagation rejects an actual APN completion')
                if closed is not None:
                    require(all(all(v is None or s[p] == v for p, v in enumerate(closed))
                                for s in compatible), 'forced assignment loses an APN completion')
            oracle = exhaustive_smaller(table, group)
            greedy = any(output_minimum_smaller(table, a) for a in group)
            witness = smaller_witness(table, n)
            require(oracle == greedy == (witness is not None), 'sparse affine oracles disagree')
            if witness is not None:
                require(comparable_smaller(table, *witness), 'invalid sparse rejection witness')
                rejected += 1
            for poison in (0, q - 1, 255):
                require(kernel.smaller(table, n, poison=poison) == oracle,
                        'compiled sparse filter differs from full affine group action')
            count += 1
        checks.append(dict(check='all_sparse_templates', dimension=n, templates=count,
                           affine_rejected=rejected, closure_modes=3,
                           completion_oracle_apn_count=len(full_apn)))

    # Deterministic samples include arbitrary holes and values, as well as all
    # domains of an actual n=3 APN permutation. Full input maps, with a greedy
    # complete output map, supply an independent affine oracle.
    rng = Random(2007)
    group3 = tuple(affine_permutations(3))
    apn3 = (0, 1, 2, 4, 3, 6, 7, 5)
    samples = [tuple(apn3[p] if mask & (1 << p) else None for p in range(8))
               for mask in range(256)]
    samples += [tuple(rng.choice([None] + list(range(8))) for _ in range(8)) for _ in range(128)]
    extra_hit = None
    for table in samples:
        for normalized, permutations in ((False, False), (True, False), (False, True)):
            check_closure(table, normalized, permutations)
        oracle = any(output_minimum_smaller(table, a) for a in group3)
        witness = smaller_witness(table, 3)
        require((witness is not None) == oracle == kernel.smaller(table, 3, poison=255),
                'n=3 sparse affine comparison fails')
        if witness is not None:
            require(comparable_smaller(table, *witness), 'invalid n=3 sparse witness')
        first_hole = next((p for p, v in enumerate(table) if v is None), 8)
        if oracle and not kernel.smaller(table[:first_hole], 3):
            extra_hit = dict(template=table, prefix_length=first_hole, alpha=witness[0], beta=witness[1])
    require(extra_hit is not None, 'test set never exercises an extra sparse-template rejection')
    checks.append(dict(check='n3_sparse_samples', templates=len(samples), additional_rejection=extra_hit))

    # A degree-three power map in explicit polynomial coordinates provides
    # known APN completions in n=5, including values/positions at mask bit 31.
    def multiply(a, b):
        result = 0
        while b:
            if b & 1:
                result ^= a
            b >>= 1
            a <<= 1
            if a & 32:
                a ^= 0b100101
        return result

    gold5 = tuple(multiply(multiply(x, x), x) for x in range(32))
    require(is_apn_derivatives(gold5), 'n5 completion fixture is not APN')
    large_templates = [tuple(gold5[p] if p != missing else None for p in range(32))
                       for missing in range(32)]
    large_templates += [tuple(v if rng.randrange(4) else None for v in gold5) for _ in range(48)]
    forced_example = None
    for table in large_templates:
        closed = check_closure(table)
        require(closed is not None and all(v is None or v == gold5[p] for p, v in enumerate(closed)),
                'n5 propagation loses known APN completion')
        if table != closed and None in table:
            first_hole = table.index(None)
            later = [p for p in range(first_hole + 1, 32) if table[p] is None and closed[p] is not None]
            if later:
                forced_example = dict(before=table, after=closed, forced_beyond_first_hole=later)
    require(forced_example is not None, 'n5 fixture did not exercise propagation beyond the first hole')
    checks.append(dict(check='n5_high_bit_closure', templates=len(large_templates), example=forced_example))

    for n, normalized, permutations in ((1, True, False), (2, True, False),
                                        (3, True, False), (4, True, False),
                                        (3, False, True), (4, False, True)):
        expected = list(search_apn(n, normalized=normalized, permutations=permutations))
        readable = list(search_propagated(n, normalized=normalized, permutations=permutations))
        require(readable == expected, 'readable propagation changes complete candidate list')
        encoded = b''.join(bytes(s) for s in expected)
        for poison in (0, 255):
            data, stats, work = kernel.search(n, normalized=normalized, permutations=permutations,
                                               poison=poison, propagation=True)
            require(data == encoded, 'compiled propagation changes complete candidate list')
            require(work['apn_completions'] - work['complete_affine_rejected'] == len(expected),
                    'propagated leaf accounting fails')
        checks.append(dict(check='complete_propagated_search', dimension=n,
                           normalized=normalized, permutations=permutations, candidates=len(expected)))

    for n, cutoffs in ((2, range(1, 5)), (3, range(1, 9)), (4, (1, 11, 12, 15, 16))):
        q = 1 << n
        expected = b''.join(bytes(s) for s in search_apn(n, normalized=True))
        for cutoff in cutoffs:
            data, stats, work = kernel.search(n, cutoff=cutoff, propagation=True, poison=255)
            require(data == expected, 'propagation/cutoff changes candidate list')
            for i, (tested, skipped) in enumerate(zip(work['affine_checks_by_depth'],
                                                     work['affine_skips_by_depth'])):
                require(tested == 0 if cutoff <= i + 1 < q else skipped == 0,
                        'propagated cutoff does not use known-entry count')
            require(work['apn_completions'] == work['affine_checks_by_depth'][-1],
                    'propagated completion escaped final affine check')
            require(work['apn_completions'] - work['complete_affine_rejected'] == len(data) // q,
                    'propagated completion count mismatch')
            checks.append(dict(check='propagated_cutoff_invariance', dimension=n,
                cutoff=cutoff, candidates=len(data) // q, work=work))
    return checks
