"""Absolute Walsh spectra with an explicit output-mask convention.

Coordinates are bits of integer labels. No finite-field basis is required.
The direct and fast implementations are kept independent for cross-checking.
"""
from collections import Counter
from apn_reference import validate_table


def absolute_walsh_spectrum(table, *, nonzero_output=True, method='fast'):
    """Count |sum_x (-1)^(a.x + b.s(x))| over a and the selected b.

    By default b=0 is excluded. Including it adds q-1 zeros and one q.
    """
    validate_table(table)
    if method not in ('fast', 'direct'):
        raise ValueError('method must be fast or direct')
    q = len(table)
    spectrum = Counter()
    for b in range(1 if nonzero_output else 0, q):
        if method == 'direct':
            for a in range(q):
                coefficient = sum(1 if ((a & x).bit_count() + (b & table[x]).bit_count()) % 2 == 0
                                  else -1 for x in range(q))
                spectrum[abs(coefficient)] += 1
        else:
            values = [1 if (b & image).bit_count() % 2 == 0 else -1 for image in table]
            step = 1
            while step < q:
                for block in range(0, q, 2 * step):
                    for i in range(block, block + step):
                        left, right = values[i], values[i + step]
                        values[i], values[i + step] = left + right, left - right
                step *= 2
            if sum(v * v for v in values) != q * q:
                raise RuntimeError('Walsh Parseval identity fails')
            spectrum.update(abs(v) for v in values)
    return spectrum


def algebraic_degree_by_subsets(table):
    """Independent ANF coefficients by directly summing all subsets."""
    validate_table(table)
    degree = 0
    for mask in range(len(table)):
        coefficient = 0
        subset = mask
        while True:
            coefficient ^= table[subset]
            if subset == 0:
                break
            subset = (subset - 1) & mask
        if coefficient:
            degree = max(degree, mask.bit_count())
    return degree
