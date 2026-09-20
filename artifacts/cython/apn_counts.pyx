# cython: language_level=3
# distutils: extra_compile_args = -O3
"""Bounded APN baseline: incremental rollback and independent full enumeration.

Dimensions 1..3 only. The immutable plane-based reference is separate code.
"""
from libc.stdint cimport uint8_t, uint16_t, uint64_t
from libc.string cimport memset

cdef class Search:
    cdef unsigned q
    cdef uint8_t table[8]
    cdef uint16_t differences[8]
    cdef uint64_t count, permutations
    cdef uint64_t attempted[8]
    cdef uint64_t accepted[8]
    cdef uint64_t rejected[8]
    cdef bytearray output

    cdef void record(self) except *:
        cdef unsigned i
        cdef uint16_t image = 0
        self.count += 1
        for i in range(self.q):
            image |= 1 << self.table[i]
        if image == (1 << self.q) - 1:
            self.permutations += 1
        self.output.extend((<char *>self.table)[:self.q])

    cdef void incremental(self, unsigned depth) except *:
        cdef unsigned value, written, a, b
        cdef uint16_t bit
        if depth == self.q:
            self.record()
            return
        for value in range(self.q):
            written = 0
            self.attempted[depth] += 1
            self.table[depth] = value
            while written < depth:
                a = depth ^ written
                b = value ^ self.table[written]
                bit = 1 << b
                if self.differences[a] & bit:
                    break
                self.differences[a] |= bit
                written += 1
            if written == depth:
                self.accepted[depth] += 1
                self.incremental(depth + 1)
            else:
                self.rejected[depth] += 1
            # Do not remove the existing bit that caused a conflict.
            while written > 0:
                written -= 1
                a = depth ^ written
                b = value ^ self.table[written]
                self.differences[a] &= ~(1 << b)

    cdef bint derivative_definition(self) noexcept:
        cdef unsigned a, x, b
        cdef uint8_t multiplicity[8]
        for a in range(1, self.q):
            memset(multiplicity, 0, sizeof(multiplicity))
            for x in range(self.q):
                b = self.table[x] ^ self.table[x ^ a]
                multiplicity[b] += 1
                if multiplicity[b] > 2:
                    return False
        return True

    cdef void exhaustive(self, unsigned depth) except *:
        cdef unsigned value
        if depth == self.q:
            if self.derivative_definition():
                self.record()
            return
        for value in range(self.q):
            self.table[depth] = value
            self.exhaustive(depth + 1)


def enumerate_tables(n, method='incremental'):
    """Return serialized tables and statistics; each call owns fresh state."""
    if not isinstance(n, int) or not 1 <= n <= 3:
        raise ValueError('baseline dimension must be 1, 2, or 3')
    if method not in ('incremental', 'exhaustive'):
        raise ValueError('unknown enumeration method')
    cdef Search search = Search()  # C fields zero-initialized by Cython.
    search.q = 1 << n
    search.output = bytearray()
    if method == 'incremental':
        search.incremental(0)
    else:
        search.exhaustive(0)
    if any(search.differences[i] != 0 for i in range(search.q)):
        raise RuntimeError('rollback invariant failed')
    report = dict(dimension=n, method=method, count=search.count,
                  permutations=search.permutations)
    if method == 'incremental':
        report.update(attempted=[search.attempted[i] for i in range(search.q)],
                      accepted=[search.accepted[i] for i in range(search.q)],
                      rejected=[search.rejected[i] for i in range(search.q)])
    return bytes(search.output), report
