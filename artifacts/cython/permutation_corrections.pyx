# cython: language_level=3
# distutils: extra_compile_args = -O3
"""Prune a linear-column search only at collisions in s+L."""
from libc.stdint cimport uint8_t, uint64_t
from cpython.exc cimport PyErr_CheckSignals

cdef class Search:
    cdef unsigned q
    cdef uint8_t s[32]
    cdef uint8_t correction[32]
    cdef uint64_t attempts, count
    cdef bytearray output

    cdef int walk(self, unsigned size, uint64_t images) except -1:
        cdef unsigned column, x, y
        cdef uint64_t mask
        cdef bint ok
        if size == self.q:
            self.count += 1
            self.output.extend(self.correction[i] for i in range(self.q))
            return 0
        if size == 2:
            PyErr_CheckSignals()
        for column in range(self.q):
            self.attempts += 1
            mask = images
            ok = True
            for x in range(size):
                self.correction[size+x] = self.correction[x] ^ column
                y = self.s[size+x] ^ self.correction[size+x]
                if mask & (<uint64_t>1 << y):
                    ok = False
                    break
                mask |= <uint64_t>1 << y
            if ok:
                self.walk(2*size, mask)
        return 0


def search(table):
    q = len(table)
    if q < 2 or q > 32 or q & (q-1) or any(not isinstance(v,int) or not 0 <= v < q for v in table):
        raise ValueError('expected a table in dimension 1..5')
    cdef Search state = Search()
    state.q = q
    state.output = bytearray()
    for i,v in enumerate(table):
        state.s[i] = v
    state.correction[0] = 0
    state.walk(1, <uint64_t>1 << state.s[0])
    return bytes(state.output), dict(corrections=int(state.count), column_attempts=int(state.attempts))
