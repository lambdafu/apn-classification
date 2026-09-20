"""Finite independent checks for the historical three-template reconstruction."""
from itertools import permutations, product
from affine_oracle import affine_permutations
from ea_equivalence import verify_ea_witness
from historical_stabilizer import (search, orbit_filter, permutation_group,
                                   stabilizer_orbits, canonical_generators)


def verify_kernel(kernel):
    tables = list(product(range(4), repeat=4))
    for source in tables:
        for target in tables:
            expected = ((source[0] ^ source[1] ^ source[2] ^ source[3]) == 0) == (
                (target[0] ^ target[1] ^ target[2] ^ target[3]) == 0)
            witness, _ = kernel.search(source, target)
            if (witness is not None) != expected:
                raise RuntimeError('n=2 ANF orbit oracle disagrees')
            if witness is not None:
                verify_ea_witness(source, target, witness)
                if tuple(witness[0]) != tuple(range(4)):
                    raise RuntimeError('n=2 least alpha must be the identity')
        for target in ((0, 0, 0, 0), (0, 0, 0, 1)):
            a, _ = search(source, target)
            b, _ = kernel.search(source, target)
            if (a is None) != (b is None) or (a is not None and a[0] != b[0]):
                raise RuntimeError('readable and compiled searches disagree')
            for witness in (a,b):
                if witness is not None:
                    verify_ea_witness(source,target,witness)
            c, _ = kernel.search(source,target,propagation=False)
            d, _ = search(source,target,propagation=True)
            if a != c or b != d:
                raise RuntimeError('propagation schedules disagree with their references')
    groups = [permutation_group(gens, 4) for gens in
              ([], [(1, 0, 2, 3)], [(1, 2, 3, 0)],
               [(1, 0, 3, 2), (2, 3, 0, 1)],
               [(1, 0, 2, 3), (1, 2, 3, 0)])]
    full, partial = 0, 0
    for group in groups:
        elements = [tuple(int(g(x + 1)) - 1 for x in range(4)) for g in group]
        orbits = stabilizer_orbits(group, 4)
        for alpha in permutations(range(4)):
            least = min(tuple(alpha[h[x]] for x in range(4)) for h in elements)
            if orbit_filter(alpha, orbits) != (alpha == least):
                raise RuntimeError('orbit criterion disagrees with full right action')
            full += 1
            if alpha == least:
                for mask in range(16):
                    template = tuple(alpha[x] if mask & (1 << x) else None for x in range(4))
                    if not orbit_filter(template, orbits):
                        raise RuntimeError('pruning rejects a canonical completion')
                    partial += 1
    table = (0, 0, 0, 1, 0, 2, 4, 7)
    a, agens, _ = canonical_generators(table)
    b, bgens, _ = canonical_generators(table, kernel.search)
    # The independent full affine enumeration has 1344 elements. Verify an
    # EA lift for each by exhausting all 168 linear output permutations.
    from affine_oracle import linear_permutations
    from code_classification import affine_table
    betas = list(linear_permutations(3))
    expected = []
    for alpha in affine_permutations(3):
        for beta in betas:
            gamma = tuple(table[x] ^ beta[table[alpha[x]]] for x in range(8))
            if affine_table(gamma):
                expected.append(tuple(alpha))
                break
    actual = {tuple(int(g(x + 1)) - 1 for x in range(8)) for g in a}
    if actual != set(expected) or a != b or agens != bgens:
        raise RuntimeError('n=3 independent full stabilizer comparison fails')
    return [dict(check='all_n2_ordered_pairs_against_ANF_oracle', pairs=65536,
                 least_alpha_checked=True),
            dict(check='n2_readable_compiled_witnesses_both_propagation_schedules', pairs=512),
            dict(check='full_group_action_and_partial_template_pruning',
                 groups=len(groups), complete_permutations=full,
                 restrictions_of_canonical_permutations=partial),
            dict(check='n3_exhaustive_affine_input_and_linear_output_stabilizer',
                 order=len(expected), readable_compiled_generators_agree=True)]
