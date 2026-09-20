"""Small APN searches, using immutable prefixes and the four-point criterion.

Vectors use least-significant-bit-first coordinates; addition is integer XOR.
This module deliberately does not share the C difference-table algorithm.
"""

from collections import Counter
from itertools import combinations


def validate_table(table):
    """Return the dimension of a complete, nonempty F_2^n -> F_2^n table."""
    q = len(table)
    if q < 2 or q & (q - 1):
        raise ValueError("table length must be a power of two, at least two")
    if any(not isinstance(v, int) or not 0 <= v < q for v in table):
        raise ValueError("table values must be integers in [0, len(table))")
    return q.bit_length() - 1


def is_apn_derivatives(table):
    """Definition 4.1: count all x, including both ends of each pair."""
    validate_table(table)
    q = len(table)
    for a in range(1, q):
        counts = Counter(table[x] ^ table[x ^ a] for x in range(q))
        if max(counts.values()) > 2:
            return False
    return True


def affine_planes(q):
    """Enumerate each four-point affine plane exactly once."""
    return tuple(points for points in combinations(range(q), 4)
                 if points[0] ^ points[1] ^ points[2] ^ points[3] == 0)


def is_apn_planes(table):
    """Theorem 4.3: the output sum on each affine plane is nonzero."""
    validate_table(table)
    return all(table[a] ^ table[b] ^ table[c] ^ table[d] != 0
               for a, b, c, d in affine_planes(len(table)))


def enumerate_apn(n, stats=None):
    """Yield every APN table in lexicographic order, without normalization.

    At position d, exclude exactly the values completing a zero output sum
    on a plane whose largest input is d. Earlier planes have already passed.
    Prefixes are immutable: this reference has no state to roll back.
    Dimensions are intentionally limited to the small exhaustive baseline.
    """
    if not isinstance(n, int) or not 1 <= n <= 3:
        raise ValueError("this baseline supports dimensions 1 through 3")
    q = 1 << n
    triples = tuple(tuple((a, b, c) for a, b, c in combinations(range(d), 3)
                          if a ^ b ^ c == d) for d in range(q))
    if stats is None:
        stats = {}
    stats.update(attempted=[0] * q, accepted=[0] * q, rejected=[0] * q)

    def extend(prefix):
        d = len(prefix)
        if d == q:
            yield prefix
            return
        forbidden = {prefix[a] ^ prefix[b] ^ prefix[c]
                     for a, b, c in triples[d]}
        for value in range(q):
            stats["attempted"][d] += 1
            if value in forbidden:
                stats["rejected"][d] += 1
                continue
            stats["accepted"][d] += 1
            yield from extend(prefix + (value,))

    yield from extend(())

