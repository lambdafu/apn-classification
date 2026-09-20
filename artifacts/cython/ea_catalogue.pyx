# cython: language_level=3
# distutils: extra_compile_args = -O3
"""Full-map enumeration; readable specification in lib/ea_catalogue.py."""
from libc.stdint cimport uint8_t, uint32_t, uint64_t
from cpython.exc cimport PyErr_CheckSignals


cdef class Enumeration:
    cdef unsigned n, q
    cdef uint8_t s[16], linear[16], correction[16]
    cdef uint64_t count, maps
    cdef bint canonical

    cdef int inspect(self) except -1:
        cdef unsigned shift, x, i, j, u, rank, origin, mask, size, c
        cdef uint8_t mapping[16], members[16], coefficients[4]
        cdef int comparison
        for shift in range(self.q):
            self.maps += 1
            origin = self.s[shift]
            for i in range(self.n):
                coefficients[i] = self.s[self.linear[1 << i] ^ shift] ^ origin
            rank = 0
            mask = 1
            size = 1
            members[0] = 0
            mapping[0] = 0
            comparison = 0
            for x in range(self.q):
                u = self.s[self.linear[x] ^ shift] ^ origin
                for i in range(self.n):
                    if x & (1 << i):
                        u ^= coefficients[i]
                if not (mask & (1U << u)):
                    for j in range(size):
                        c = members[j] ^ u
                        mapping[c] = mapping[members[j]] ^ (1U << rank)
                        members[size+j] = c
                        mask |= 1U << c
                    size *= 2
                    rank += 1
                if mapping[u] != self.s[x]:
                    comparison = -1 if mapping[u] < self.s[x] else 1
                    break
            if comparison < 0:
                self.canonical = False
                return 0
            if comparison == 0:
                self.count += 1
        return 0

    cdef int bases(self, unsigned size, unsigned mask) except -1:
        cdef unsigned value, x, new_mask
        if size == self.q:
            return self.inspect()
        if size == 2:
            PyErr_CheckSignals()
        for value in range(1, self.q):
            if mask & (1U << value):
                continue
            new_mask = mask
            for x in range(size):
                self.linear[size+x] = self.linear[x] ^ value
                new_mask |= 1U << self.linear[size+x]
            self.bases(2*size, new_mask)
            if not self.canonical:
                break
        return 0

    cdef bint bijective(self, unsigned size, unsigned images) noexcept:
        cdef unsigned column, x, y, mask
        cdef bint ok
        if size == self.q:
            return True
        for column in range(self.q):
            mask = images
            ok = True
            for x in range(size):
                self.correction[size+x] = self.correction[x] ^ column
                y = self.s[size+x] ^ self.correction[size+x]
                if mask & (1U << y):
                    ok = False
                    break
                mask |= 1U << y
            if ok and self.bijective(2*size, mask):
                return True
        return False


def analyze(table):
    from ea_catalogue import validate_normalized, normalize_output
    n = validate_normalized(table)
    if normalize_output(table)[0] != tuple(table):
        return dict(canonical=False, input_stabilizer=None, affine_maps=0)
    cdef Enumeration state = Enumeration()
    state.n, state.q = n, len(table)
    for i, v in enumerate(table):
        state.s[i] = v
    state.canonical = True
    state.linear[0] = 0
    state.bases(1, 1)
    return dict(canonical=bool(state.canonical),
                input_stabilizer=int(state.count) if state.canonical else None,
                affine_maps=int(state.maps))


def permutation_correction(table):
    from ea_catalogue import validate_normalized
    n = validate_normalized(table)
    cdef Enumeration state = Enumeration()
    state.n, state.q = n, len(table)
    for i, v in enumerate(table):
        state.s[i] = v
    state.correction[0] = 0
    if state.bijective(1, 1U << state.s[0]):
        return [state.correction[i] for i in range(state.q)]
    return None
