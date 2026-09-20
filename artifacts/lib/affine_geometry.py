"""Exact plane counts for the thesis's integer-ordered binary vector spaces."""
from functools import lru_cache
from itertools import combinations
from math import comb


def planes_in(points):
    """Every unordered four-point plane, represented as a sorted tuple."""
    points = tuple(sorted(set(points)))
    return tuple((a, b, c, d) for a, b, c, d in combinations(points, 4)
                 if a ^ b ^ c ^ d == 0)


@lru_cache(maxsize=None)
def prefix_count(k):
    """A(k), thesis Proposition 3.7; integer arithmetic including base cases."""
    if not isinstance(k, int) or k < 0:
        raise ValueError("prefix size must be a nonnegative integer")
    if k < 4:
        return 0
    h = 1 << ((k - 1).bit_length() - 1)
    r = k - h
    return prefix_count(h) + prefix_count(r) + comb(r, 2) * (h // 2)


@lru_cache(maxsize=None)
def new_plane_count(k):
    """Delta(k), from its own recurrence, not by differencing prefix_count."""
    if not isinstance(k, int) or k < 0:
        raise ValueError("prefix size must be a nonnegative integer")
    if k < 4:
        return 0
    h = 1 << ((k - 1).bit_length() - 1)
    r = k - h
    return new_plane_count(r) + (r - 1) * (h // 2)


def subset_extrema(n, planes):
    """Check the bound on every subset, returning maxima by cardinality.

    This enumerates subsets of the input space, not vectorial functions.
    Counts come only from direct containment tests, independently of A(k).
    """
    if not isinstance(n, int) or not 1 <= n <= 4:
        raise ValueError("all-subset verification supports dimensions 1 through 4")
    q = 1 << n
    plane_masks = [sum(1 << x for x in plane) for plane in planes]
    maxima = [-1] * (q + 1)
    witnesses = [None] * (q + 1)
    for subset in range(1 << q):
        count = sum(subset & plane == plane for plane in plane_masks)
        size = subset.bit_count()
        if count > maxima[size]:
            maxima[size] = count
            witnesses[size] = [x for x in range(q) if subset & (1 << x)]
    return {"subsets_checked": 1 << q, "maxima": maxima, "witnesses": witnesses}

