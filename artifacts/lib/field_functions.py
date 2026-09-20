"""Binary polynomial arithmetic for independent power/family certificate replay.

Bit i is the coefficient of z^i. These routines do not use Sage or the EA
search, and deliberately favor readable arithmetic over acceleration.
"""


MODULI = {4: 0b10011, 5: 0b100101}  # z^4+z+1; z^5+z^2+1


def multiply(a, b, n):
    result = 0
    while b:
        if b & 1:
            result ^= a
        b >>= 1
        a <<= 1
        if a & (1 << n):
            a ^= MODULI[n]
    return result


def power(x, exponent, n):
    result = 1
    while exponent:
        if exponent & 1:
            result = multiply(result, x, n)
        x = multiply(x, x, n)
        exponent >>= 1
    return result


def trace(x, n):
    result = 0
    for _ in range(n):
        result ^= x
        x = multiply(x, x, n)
    if result not in (0, 1):
        raise ValueError('absolute trace is not binary')
    return result


def power_table(n, exponent):
    return [power(x, exponent, n) for x in range(1 << n)]


def family_table(n, i):
    """Article equations (5), (6), restricted to their stated small cases."""
    if (n, i) not in ((4, 1), (5, 1), (5, 2)):
        raise ValueError('unsupported family instance')
    result = []
    for x in range(1 << n):
        gold = power(x, (1 << i) + 1, n)
        factor = power(x, 1 << i, n) ^ x ^ (1 if n == 4 else 0)
        argument = gold ^ (x if n == 5 else 0)
        result.append(gold ^ multiply(factor, trace(argument, n), n))
    return result
