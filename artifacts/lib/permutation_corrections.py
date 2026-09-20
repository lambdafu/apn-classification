"""Enumerate every linear correction L for which s+L is a permutation."""
from itertools import product


def all_corrections(table):
    q = len(table)
    if q < 2 or q > 32 or q & (q-1) or any(not isinstance(v,int) or not 0 <= v < q for v in table):
        raise ValueError('expected a table in dimension 1..5')
    n = q.bit_length()-1
    for columns in product(range(q), repeat=n):
        linear = [0]
        for column in columns:
            linear += [x ^ column for x in linear]
        if len({a ^ b for a,b in zip(table,linear)}) == q:
            yield tuple(linear)
