# cython: language_level=3, boundscheck=False, wraparound=False, cdivision=True
# distutils: extra_compile_args = -O3
"""Walsh extension enumeration and residual two-component feasibility.

See lib/components.py for the integer reference operations and methods notes
for coverage. All buffers are private to this independent implementation.
"""
from libc.stdint cimport uint8_t, uint32_t, uint64_t, int16_t, int8_t
from libc.stdlib cimport calloc, malloc, free
from cpython.exc cimport PyErr_CheckSignals

cdef extern from *:
    int __builtin_popcount(unsigned int) noexcept
    int __builtin_ctz(unsigned int) noexcept


cdef class Residual:
    cdef uint32_t constraints[1240]
    cdef unsigned count, q
    cdef uint64_t nodes
    cdef int8_t solution[32]

    cdef bint visit(self, int8_t* parent, uint8_t* available) except -1:
        cdef int8_t values[32]
        cdef uint8_t domains[32]
        cdef unsigned i, mask, p, missing, position, value, parity, size, best, choices, used, first
        cdef bint changed
        self.nodes += 1
        if self.nodes & 65535 == 0:
            PyErr_CheckSignals()
        for i in range(self.q):
            values[i] = parent[i]
            domains[i] = available[i]
        changed = True
        while changed:
            changed = False
            for i in range(self.count):
                mask = self.constraints[i]
                missing = 0
                parity = 0
                while mask:
                    p = __builtin_ctz(mask)
                    mask &= mask - 1
                    if values[p] < 0:
                        missing += 1
                        position = p
                    else:
                        parity ^= values[p]
                if missing == 0:
                    if parity == 0:
                        return False
                elif missing == 1:
                    domains[position] &= <uint8_t>~(1U << parity)
                    if domains[position] == 0:
                        return False
                    if (domains[position] & (domains[position] - 1)) == 0:
                        values[position] = __builtin_ctz(domains[position])
                        changed = True
        best = 5
        position = self.q
        for i in range(self.q):
            if values[i] < 0:
                size = __builtin_popcount(domains[i])
                if size < best:
                    best = size
                    position = i
        if position == self.q:
            for i in range(self.q):
                self.solution[i] = values[i]
            return True
        choices = domains[position]
        # GL(2,2) fixes zero and permutes the three nonzero colors. Restrict
        # the first new color to the least unused one; propagation never
        # forces a color outside the span of already assigned colors.
        used = 1
        for i in range(self.q):
            if values[i] >= 0:
                used |= 1U << values[i]
        if __builtin_popcount(used) <= 2:
            first = 1
            while used & (1U << first):
                first += 1
            choices &= used | (1U << first)
        while choices:
            value = __builtin_ctz(choices)
            choices &= choices - 1
            values[position] = value
            if self.visit(values, domains):
                return True
        return False

    cdef bint solve(self, uint32_t* planes, unsigned count, uint32_t pivots, unsigned q=32) except -1:
        cdef unsigned i
        cdef int8_t values[32]
        cdef uint8_t domains[32]
        self.count = count
        self.q = q
        for i in range(count):
            self.constraints[i] = planes[i]
        for i in range(q):
            values[i] = 0 if pivots & (1U << i) else -1
            domains[i] = 15
        return self.visit(values, domains)


def feasible_two(words, n=5):
    from components import unresolved, quotient
    cdef Residual state = Residual()
    cdef uint32_t masks[1240]
    cdef unsigned i, count
    if not 2 <= n <= 5 or len(words) != n-2:
        raise ValueError('expected n-2 existing components, 2<=n<=5')
    pending = unresolved(words, n)
    count = len(pending)
    for i in range(count):
        masks[i] = pending[i]
    pivots = sum(1 << i for i in quotient(words, n)[0])
    if not state.solve(masks, count, pivots, 1 << n):
        return None, int(state.nodes)
    return [sum((int(state.solution[i]) >> j & 1) << i for i in range(1 << n)) for j in range(2)], int(state.nodes)


def enumerate_extensions(words, int n=5, generators=None, bint capacity=True,
                         bint finish_two=False):
    from components import unresolved, quotient, pack, unpack, reduce, transform, table
    if n > 5 or len(words) >= n:
        raise ValueError('supported range: output dimension < input dimension <=5')
    basis, positions = quotient(words, n)
    pending = unresolved(words, n)
    cdef unsigned width = len(positions), length = 1U << width
    cdef unsigned i, j, k, stride, start, index, image, head, tail, g, ng
    cdef unsigned pos[32]
    cdef uint32_t masks[1240]
    cdef uint32_t residual[1240]
    cdef uint32_t pivots, word, bits, transform_index
    cdef unsigned count = len(pending), remaining, a, x, b, v, cap, q = 1U << n
    cdef unsigned low_values[32]
    cdef unsigned values[32]
    cdef unsigned bins[32]
    cdef unsigned level = len(words)
    cdef int denominator = (1 << (n - level)) - 1
    cdef int left, right
    cdef uint64_t raw_count=0, orbit_count=0, capacity_count=0, feasible_count=0
    cdef bint ok
    cdef int16_t* scores = <int16_t*>calloc(length, sizeof(int16_t))
    cdef uint32_t* queue = NULL
    cdef uint32_t* actions = NULL
    cdef Residual solver = Residual()
    if scores == NULL:
        raise MemoryError()
    output = []
    witnesses = []
    ng = 0 if generators is None else len(generators)
    try:
        for i in range(width):
            pos[i] = positions[i]
        for i in range(count):
            masks[i] = pending[i]
            scores[pack(pending[i], positions)] += 1
        stride = 1
        while stride < length:
            for start in range(0, length, 2 * stride):
                for j in range(stride):
                    left = scores[start+j]
                    right = scores[start+j+stride]
                    scores[start+j] = left + right
                    scores[start+j+stride] = left - right
            stride *= 2
            PyErr_CheckSignals()
        for i in range(1, length):
            if scores[i] * denominator <= -<int>count:
                raw_count += 1
        if ng:
            queue = <uint32_t*>malloc(length * sizeof(uint32_t))
            actions = <uint32_t*>calloc(ng * 4 * 256, sizeof(uint32_t))
            if queue == NULL or actions == NULL:
                raise MemoryError()
            for g in range(ng):
                columns = [pack(reduce(transform(1 << p, generators[g]), basis), positions) for p in positions]
                for j in range(4):
                    for i in range(256):
                        transform_index = 0
                        for k in range(8):
                            if j*8+k < width and i >> k & 1:
                                transform_index ^= columns[j*8+k]
                        actions[(g*4+j)*256+i] = transform_index
        original = table(words, n)
        for i in range(q):
            low_values[i] = original[i]
        cap = 1U << (n - level - 1)
        for index in range(1, length):
            if index & 65535 == 0:
                PyErr_CheckSignals()
            if scores[index] * denominator > -<int>count:
                continue
            orbit_count += 1
            if ng:
                head = 0
                tail = 1
                queue[0] = index
                scores[index] = 32767
                while head < tail:
                    bits = queue[head]
                    head += 1
                    for g in range(ng):
                        image = 0
                        for j in range(4):
                            image ^= actions[(g*4+j)*256+((bits >> (8*j)) & 255)]
                        if scores[image] != 32767:
                            if scores[image] * denominator > -<int>count:
                                raise RuntimeError('generator does not preserve good extensions')
                            scores[image] = 32767
                            queue[tail] = image
                            tail += 1
            word = 0
            bits = index
            while bits:
                i = __builtin_ctz(bits)
                bits &= bits - 1
                word |= 1U << pos[i]
            for x in range(q):
                values[x] = low_values[x] | ((word >> x & 1) << level)
            ok = True
            if capacity:
                for a in range(1, q):
                    for b in range(1 << (level+1)):
                        bins[b] = 0
                    for x in range(q):
                        if x < (x ^ a):
                            b = values[x] ^ values[x ^ a]
                            bins[b] += 1
                            if bins[b] > cap:
                                ok = False
                                break
                    if not ok:
                        break
            if not ok:
                continue
            capacity_count += 1
            if finish_two:
                if n != 5 or level != 2:
                    raise ValueError('two-component completion requires n=5, level=2')
                remaining = 0
                for i in range(count):
                    if __builtin_popcount(word & masks[i]) % 2 == 0:
                        residual[remaining] = masks[i]
                        remaining += 1
                # Existing quotient pivots and the first nonzero position of b.
                pivots = 0
                for i in basis:
                    pivots |= 1U << <unsigned>i
                pivots |= 1U << __builtin_ctz(word)
                if not solver.solve(residual, remaining, pivots):
                    continue
                witnesses.append([sum((int(solver.solution[i]) >> j & 1) << i for i in range(32)) for j in range(2)])
            feasible_count += 1
            output.append(int(word))
        return dict(words=output, witnesses=witnesses, quotient_dimension=width,
                    unresolved_planes=count, raw_extensions=int(raw_count),
                    orbit_extensions=int(orbit_count), capacity_survivors=int(capacity_count),
                    feasible_survivors=int(feasible_count), completion_nodes=int(solver.nodes))
    finally:
        free(scores)
        free(queue)
        free(actions)
