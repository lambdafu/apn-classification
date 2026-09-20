"""Full affine-input enumeration for normalized EA representatives, n<=4.

This is an independent verification algorithm, not the original pruned
enumeration of all functions. Immutable reference for ea_catalogue.pyx.
"""
from itertools import product
from math import prod
from affine_oracle import affine_permutations


def validate_normalized(table):
    q = len(table)
    if q not in (2, 4, 8, 16) or any(not isinstance(v, int) or not 0 <= v < q for v in table):
        raise ValueError('expected a function in dimension 1..4')
    n = q.bit_length() - 1
    if any(table[x] for x in [0] + [1 << i for i in range(n)]):
        raise ValueError('table must vanish on the standard affine basis')
    return n


def normalize_output(table):
    """Least GL image and image rank, via a greedy linear span dictionary."""
    mapping = {0: 0}
    rank = 0
    result = []
    for value in table:
        if value not in mapping:
            mapping.update({x ^ value: y ^ (1 << rank) for x, y in list(mapping.items())})
            rank += 1
        result.append(mapping[value])
    return tuple(result), rank


def normalize_input(table, alpha):
    n = len(table).bit_length() - 1
    offset = table[alpha[0]]
    columns = [table[alpha[1 << i]] ^ offset for i in range(n)]
    result = []
    for x in range(len(table)):
        value = table[alpha[x]] ^ offset
        for i in range(n):
            if x & (1 << i):
                value ^= columns[i]
        result.append(value)
    return tuple(result)


def analyze(table):
    n = validate_normalized(table)
    table = tuple(table)
    if normalize_output(table)[0] != table:
        return dict(canonical=False, input_stabilizer=None)
    count = 0
    for alpha in affine_permutations(n):
        image, _ = normalize_output(normalize_input(table, alpha))
        if image < table:
            return dict(canonical=False, input_stabilizer=None)
        count += image == table
    return dict(canonical=True, input_stabilizer=count)


def linear_table(columns):
    table = [0]
    for column in columns:
        table += [v ^ column for v in table]
    return table


def permutation_correction(table):
    """Find L with table+L bijective, or exhaust all linear maps."""
    n = validate_normalized(table)
    for columns in product(range(len(table)), repeat=n):
        correction = linear_table(columns)
        if len({a ^ b for a, b in zip(table, correction)}) == len(table):
            return correction
    return None


def orders(table, input_stabilizer):
    n = validate_normalized(table)
    q = len(table)
    rank = normalize_output(table)[1]
    kernel = prod(q - (1 << i) for i in range(rank, n))
    linear_order = prod(q - (1 << i) for i in range(n))
    action = q * linear_order**2 * q**(n + 1)
    stabilizer = input_stabilizer * kernel
    if action % stabilizer:
        raise ValueError('stabilizer order does not divide group order')
    return dict(image_rank=rank, output_kernel_order=kernel,
                stabilizer_order=stabilizer, action_order=action, orbit_size=action//stabilizer)
