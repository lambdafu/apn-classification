"""Readable three-template EA equivalence search (thesis section 4.2.4).

The output permutation beta is linear: its translation is absorbed in the
affine gamma. Composition is target(x) = beta(source(alpha(x))) XOR gamma(x).
"""
from affine_refinement import refine, complete
from apn_reference import validate_table


def algebraic_degree(table):
    """Maximum coordinate ANF degree, using an integer-vector Mobius transform."""
    n = validate_table(table)
    coefficients = list(table)
    for i in range(n):
        bit = 1 << i
        for mask in range(len(table)):
            if mask & bit:
                coefficients[mask] ^= coefficients[mask ^ bit]
    return max((mask.bit_count() for mask, c in enumerate(coefficients) if c), default=0)


def equivalence_witness(source, target):
    """Return completed (alpha,beta,gamma) or None after exact search.

    Intended for small reference checks, not yet a fast large-instance backend.
    """
    source, target = tuple(source), tuple(target)
    n = validate_table(source)
    if validate_table(target) != n:
        raise ValueError('dimensions differ')
    q = len(source)
    empty = (None,) * q
    beta0 = refine(empty, 0, 0, injective=True)

    def input_step(d, alpha, beta, gamma):
        if d == q:
            return (complete(alpha, injective=True), complete(beta, injective=True),
                    complete(gamma))
        if alpha[d] is not None:
            return output_step(d, alpha, beta, gamma)
        for value in range(q):
            if value in alpha:
                continue
            extended = refine(alpha, d, value, injective=True)
            if extended is not None:
                witness = output_step(d, extended, beta, gamma)
                if witness is not None:
                    return witness
        return None

    def output_step(d, alpha, beta, gamma):
        u = source[alpha[d]]
        if beta[u] is not None:
            return correction_step(d, alpha, beta, gamma)
        # If gamma(d) is fixed, equality forces beta(u) immediately.
        values = range(q) if gamma[d] is None else (target[d] ^ gamma[d],)
        for value in values:
            if value in beta:
                continue
            extended = refine(beta, u, value, injective=True)
            if extended is not None:
                witness = correction_step(d, alpha, extended, gamma)
                if witness is not None:
                    return witness
        return None

    def correction_step(d, alpha, beta, gamma):
        value = beta[source[alpha[d]]] ^ target[d]
        extended = refine(gamma, d, value)
        if extended is None:
            return None
        return input_step(d + 1, alpha, beta, extended)

    return input_step(0, empty, beta0, empty)

def normalized_equivalence_witness(source, target, *, translation_reduction=True):
    """Exact EA search with gamma eliminated by affine interpolation.

    This readable adaptation enumerates affine alpha, then forces linear beta
    on source(alpha(x)) plus its interpolant at zero/the standard basis. It
    avoids freely guessing beta before gamma becomes determined.
    """
    source, target = tuple(source), tuple(target)
    n = validate_table(source)
    if validate_table(target) != n:
        raise ValueError('dimensions differ')
    q = len(source)
    empty = (None,) * q
    beta0 = refine(empty, 0, 0, injective=True)
    target_normalized = []
    for x in range(q):
        value = target[x] ^ target[0]
        for i in range(n):
            if x & (1 << i):
                value ^= target[1 << i] ^ target[0]
        target_normalized.append(value)

    def step(x, alpha, beta):
        if x == q:
            beta = complete(beta, injective=True)
            gamma = tuple(target[d] ^ beta[source[alpha[d]]] for d in range(q))
            return alpha, beta, gamma
        if alpha[x] is None:
            for value in range(q):
                if value not in alpha:
                    extended = refine(alpha, x, value, injective=True)
                    if extended is not None:
                        result = step(x, extended, beta)
                        if result is not None:
                            return result
            return None
        value = source[alpha[x]] ^ source[alpha[0]]
        for i in range(n):
            if x & (1 << i):
                value ^= source[alpha[1 << i]] ^ source[alpha[0]]
        extended = refine(beta, value, target_normalized[x], injective=True)
        return None if extended is None else step(x+1, alpha, extended)

    origins = (0,) if translation_reduction and algebraic_degree(source) <= 2 else range(q)
    for origin in origins:
        alpha = refine(empty, 0, origin, injective=True)
        result = step(1, alpha, beta0)
        if result is not None:
            return result
    return None


def verify_ea_witness(source, target, witness):
    """Check complete maps directly, without template refinement or Sage."""
    n = validate_table(source)
    if validate_table(target) != n or len(witness) != 3:
        raise ValueError('invalid EA witness')
    alpha, beta, gamma = witness
    for table, invertible, linear in ((alpha, True, False), (beta, True, True), (gamma, False, False)):
        if validate_table(table) != n or (invertible and len(set(table)) != len(table)) or (linear and table[0]):
            raise ValueError('invalid EA component')
        for x, image in enumerate(table):
            expected = table[0]
            for i in range(n):
                if x & (1 << i):
                    expected ^= table[1 << i] ^ table[0]
            if image != expected:
                raise ValueError('EA component is not affine')
    if any(target[x] != beta[source[alpha[x]]] ^ gamma[x] for x in range(len(source))):
        raise ValueError('EA equation fails')
    return True
