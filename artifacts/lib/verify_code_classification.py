"""Small independent checks for the code/graph and EA-stabilizer reductions."""
from itertools import product
from affine_oracle import affine_permutations, linear_permutations
from code_classification import (affine_input_group, affine_table, binary_rank, canonical_code,
                                 ea_stabilizer, equivalent_permutation,
                                 lift_graph_permutation, require)


def verify_reductions():
    checks = []
    for n in (1, 2):
        q = 1 << n
        by_rank = {}
        fingerprints = {}
        total = 0
        for table in product(range(q), repeat=q):
            # For 2 or 4 distinct graph points, affine-span rank completely
            # determines the ambient affine orbit: a line, a plane, or four
            # affinely independent points. This oracle uses no code algorithm.
            graph_points = [x | (table[x] << n) for x in range(q)]
            rank = binary_rank([z ^ graph_points[0] for z in graph_points])
            info = canonical_code(table)
            if rank not in by_rank:
                by_rank[rank] = (table, info)
            representative, first = by_rank[rank]
            require(info['canonical_graph'] == first['canonical_graph'],
                    'code equivalence disagrees with small affine-span oracle')
            require(info['fingerprint'] not in fingerprints or fingerprints[info['fingerprint']] == rank,
                    'different small graph affine orbits were merged')
            fingerprints[info['fingerprint']] = rank
            p = equivalent_permutation(info, first)
            lift_graph_permutation(table, representative, p)
            total += 1
        checks.append(dict(check='all_small_ccz_functions', dimension=n, functions=total,
                           affine_span_ranks=sorted(by_rank), rank_deficient_lifts_checked=total))

    table = (0, 0, 0, 1, 0, 2, 4, 7)
    # Exhaustively enumerate alpha and beta; gamma is then forced pointwise.
    # This does not use codes, group intersection, or solving linear equations.
    alphas = tuple(affine_permutations(3))
    betas = tuple(linear_permutations(3))
    total = 0
    valid_alphas = set()
    for alpha in alphas:
        composed = tuple(table[alpha[x]] for x in range(8))
        for beta in betas:
            gamma = tuple(table[x] ^ beta[composed[x]] for x in range(8))
            if affine_table(gamma):
                total += 1
                valid_alphas.add(alpha)
    group = affine_input_group(3)
    result = ea_stabilizer(table, canonical_code(table), group)
    require(total == len(valid_alphas) == result['ea_stabilizer_order'],
            'EA intersection differs from exhaustive affine action')
    checks.append(dict(check='n3_exhaustive_ea_stabilizer', alpha_beta_pairs=len(alphas) * len(betas),
                       stabilizer_order=total, distinct_inputs=len(valid_alphas)))
    return checks
