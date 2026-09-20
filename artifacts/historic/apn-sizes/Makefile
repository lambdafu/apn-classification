# New build wrapper around unmodified surviving source.
# Original flags are preserved verbatim in Makefile.original.
CC = cc
CFLAGS = -O2
COMPAT_FLAGS = -Wno-implicit-function-declaration -Wno-asm-operand-widths
HISTORIC_CFLAGS = -march=core2 -mfpmath=sse -fomit-frame-pointer -ffast-math -O3

SOURCE = find-affine-aequivalent-allzero-fix-all-16.c~
DEPS = $(SOURCE) galois.c galois.h bitmask.h
PROGRAM = build/ea-stabilizer-16

TABLE1 = 0 0 0 1 0 2 4 7 0 4 6 3 8 14 10 13
TABLE2 = 0 0 0 1 0 2 4 7 0 4 6 3 8 14 11 12

.PHONY: all historic-flags check clean
all: $(PROGRAM)

$(PROGRAM): $(DEPS) Makefile
	mkdir -p build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(COMPAT_FLAGS) -x c $(SOURCE) $(LDFLAGS) $(LDLIBS) -o $@

# Requires an x86 compiler accepting the original GCC options.
# Compatibility options are additions for modern compilers, not historical flags.
historic-flags: $(DEPS) Makefile
	mkdir -p build
	$(CC) $(CPPFLAGS) $(HISTORIC_CFLAGS) $(COMPAT_FLAGS) -x c $(SOURCE) $(LDFLAGS) $(LDLIBS) -o build/ea-stabilizer-16-historic-flags

check: $(PROGRAM)
	$(PROGRAM) $(TABLE1) $(TABLE1) > build/row1.txt
	$(PROGRAM) $(TABLE2) $(TABLE2) > build/row2.txt
	@test "$$(cat build/row1.txt)" = '6818690079129600 / (5760 * 1 = 5760) = 1183800360960'
	@test "$$(cat build/row2.txt)" = '6818690079129600 / (384 * 1 = 384) = 17757005414400'
	@cat build/row1.txt build/row2.txt
	@echo 'Both dimension-four stabilizer and orbit checks passed.'

clean:
	rm -f $(PROGRAM) build/ea-stabilizer-16-historic-flags build/row1.txt build/row2.txt
