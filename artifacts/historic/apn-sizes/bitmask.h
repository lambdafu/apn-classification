#include "string.h"

#if N <= 3
/* Mask holds TWO_POWER_N bits.  */
#define MASK_DECL(sym) unsigned int sym
#define MASK_PROTO(sym) unsigned int sym
#define MASK_INV(sym) sym
#define MASK_TEST(sym,nr) (sym & (1U << (nr)))
#define MASK_SET(sym,nr) (sym |= (1U << (nr)))
#define MASK_CLEAR(sym,nr) (sym &= ~(1U << (nr)))
#define MASK_COPY(sym1,sym2) sym1 = sym2
#define MASK_RESET(sym) sym = 0

/* MASKBIG holds TWO_POWER_2N bits.  */
#define MASKBIG_PROTO(sym) \
  unsigned long long sym ## _0, unsigned long long sym ## _1, \
  unsigned long long sym ## _2, unsigned long long sym ## _3
#define MASKBIG_DECL(sym) \
  unsigned long long sym ## _0, sym ## _1, sym ## _2, sym ## _3
#define MASKBIG_INV(sym) sym ## _0, sym ## _1, sym ## _2, sym ## _3
#define MASKBIG_TEST(sym,nr) \
  (!! ((nr) < 64 ? (sym ## _0 & (1ULL << (nr))) : \
   (((nr) < 128) ? (sym ## _1 & (1ULL << ((nr) - 64))) : \
    (((nr) < 192) ? (sym ## _2 & (1ULL << ((nr) - 128))) : \
     (sym ## _3 & (1ULL << ((nr) - 192)))))))
#define MASKBIG_SET(sym,nr) \
  ((nr) < 64 ? (sym ## _0 |= (1ULL << (nr))) : \
   (((nr) < 128) ? (sym ## _1 |= (1ULL << ((nr) - 64))) : \
    (((nr) < 192) ? (sym ## _2 |= (1ULL << ((nr) - 128))) : \
     (sym ## _3 |= (1ULL << ((nr) - 192))))))
#define MASKBIG_CLEAR(sym,nr) \
  ((nr) < 64 ? (sym ## _0 &= ~(1ULL << (nr))) : \
   (((nr) < 128) ? (sym ## _1 &= ~(1ULL << ((nr) - 64))) : \
    (((nr) < 192) ? (sym ## _2 &= ~(1ULL << ((nr) - 128))) : \
     (sym ## _3 &= ~(1ULL << ((nr) - 192))))))
#define MASKBIG_COPY(sym1,sym2) \
  sym1 ## _0 = sym2 ## _0; sym1 ## _1 = sym2 ## _1; \
  sym1 ## _2 = sym2 ## _2; sym1 ## _3 = sym2 ## _3
#define MASKBIG_RESET(sym1) \
  sym1 ## _0 = 0; sym1 ## _1 = 0; \
  sym1 ## _2 = 0; sym1 ## _3 = 0
#define MASKBIG_DUMP(sym) \
  printf ("DUMP " #sym " %016llx.%016llx.%016llx.%016llx\n", sym ## _3, \
  sym ## _2, sym ## _1, sym ## _0);
#endif

#if N == 4
/* Mask holds TWO_POWER_N bits.  */
#define MASK_DECL(sym) unsigned int sym
#define MASK_PROTO(sym) unsigned int sym
#define MASK_INV(sym) sym
#define MASK_TEST(sym,nr) (sym & (1U << (nr)))
#define MASK_SET(sym,nr) (sym |= (1U << (nr)))
#define MASK_CLEAR(sym,nr) (sym &= ~(1U << (nr)))
#define MASK_COPY(sym1,sym2) sym1 = sym2
#define MASK_RESET(sym) sym = 0

/* MASKBIG holds TWO_POWER_2N bits.  */
#define MASKBIG_PROTO(sym) \
  unsigned long long sym ## _0, unsigned long long sym ## _1, \
  unsigned long long sym ## _2, unsigned long long sym ## _3
#define MASKBIG_DECL(sym) \
  unsigned long long sym ## _0, sym ## _1, sym ## _2, sym ## _3
#define MASKBIG_INV(sym) sym ## _0, sym ## _1, sym ## _2, sym ## _3
#define MASKBIG_TEST(sym,nr) \
  (!! ((nr) < 64 ? (sym ## _0 & (1ULL << (nr))) : \
   (((nr) < 128) ? (sym ## _1 & (1ULL << ((nr) - 64))) : \
    (((nr) < 192) ? (sym ## _2 & (1ULL << ((nr) - 128))) : \
     (sym ## _3 & (1ULL << ((nr) - 192)))))))
#define MASKBIG_SET(sym,nr) \
  ((nr) < 64 ? (sym ## _0 |= (1ULL << (nr))) : \
   (((nr) < 128) ? (sym ## _1 |= (1ULL << ((nr) - 64))) : \
    (((nr) < 192) ? (sym ## _2 |= (1ULL << ((nr) - 128))) : \
     (sym ## _3 |= (1ULL << ((nr) - 192))))))
#define MASKBIG_CLEAR(sym,nr) \
  ((nr) < 64 ? (sym ## _0 &= ~(1ULL << (nr))) : \
   (((nr) < 128) ? (sym ## _1 &= ~(1ULL << ((nr) - 64))) : \
    (((nr) < 192) ? (sym ## _2 &= ~(1ULL << ((nr) - 128))) : \
     (sym ## _3 &= ~(1ULL << ((nr) - 192))))))
#define MASKBIG_COPY(sym1,sym2) \
  sym1 ## _0 = sym2 ## _0; sym1 ## _1 = sym2 ## _1; \
  sym1 ## _2 = sym2 ## _2; sym1 ## _3 = sym2 ## _3
#define MASKBIG_RESET(sym1) \
  sym1 ## _0 = 0; sym1 ## _1 = 0; \
  sym1 ## _2 = 0; sym1 ## _3 = 0
#define MASKBIG_DUMP(sym) \
  printf ("DUMP " #sym " %016llx.%016llx.%016llx.%016llx\n", sym ## _3, \
  sym ## _2, sym ## _1, sym ## _0);
#endif

#if N == 5
#define MASK_DECL(sym) unsigned long sym
#define MASK_PROTO(sym) unsigned long sym
#define MASK_INV(sym) sym
#define MASK_TEST(sym,nr) (!!(sym & (1UL << (nr))))
#define MASK_SET(sym,nr) (sym |= (1UL << (nr)))
#define MASK_CLEAR(sym,nr) (sym &= ~(1UL << (nr)))
#define MASK_COPY(sym1,sym2) sym1 = sym2
#define MASK_RESET(sym) sym = 0

/* MASKBIG holds TWO_POWER_2N bits.  */
/* 2^(2*5) / 64 == 16 ull words.  */
#define MASKBIG_PROTO(sym) unsigned long long *sym
#define MASKBIG_DECL(sym) unsigned long long sym[16]
#define MASKBIG_INV(sym) sym
#define MASKBIG_TEST(sym,nr) \
  (!! (sym[((nr) >> 6) & 15] & (1ULL << ((nr) & 63))))
#define MASKBIG_SET(sym,nr) \
  (sym[((nr) >> 6) & 15] |= (1ULL << ((nr) & 63)))
#define MASKBIG_CLEAR(sym,nr) \
  (sym[((nr) >> 6) & 15] &= ~(1ULL << ((nr) & 63)))
#define MASKBIG_COPY(sym1,sym2) \
  memcpy (sym1, sym2, sizeof (unsigned long long) * 16)
#define MASKBIG_RESET(sym) \
  memset (sym, 0, sizeof (unsigned long long) * 16)
#endif

#if N == 6
#define MASK_DECL(sym) unsigned long long sym
#define MASK_PROTO(sym) unsigned long long sym
#define MASK_INV(sym) sym
#define MASK_TEST(sym,nr) (!!(sym & (1ULL << (nr))))
#define MASK_SET(sym,nr) (sym |= (1ULL << (nr)))
#define MASK_CLEAR(sym,nr) (sym &= ~(1ULL << (nr)))
#define MASK_COPY(sym1,sym2) sym1 = sym2
#define MASK_RESET(sym) sym = 0

#define WIDTH2 64
#define MASKBIG_PROTO(sym) unsigned long long *sym
#define MASKBIG_DECL(sym) unsigned long long sym[WIDTH2]
#define MASKBIG_INV(sym) sym
#define MASKBIG_TEST(sym,nr) \
  (!! (sym[((nr) >> 6) & (WIDTH2 - 1)] & (1ULL << ((nr) & 63))))
#define MASKBIG_SET(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH2 - 1)] |= (1ULL << ((nr) & 63)))
#define MASKBIG_CLEAR(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH2 - 1)] &= ~(1ULL << ((nr) & 63)))
#define MASKBIG_COPY(sym1,sym2) \
  memcpy (sym1, sym2, sizeof (unsigned long long) * WIDTH2)
#define MASKBIG_RESET(sym) \
  memset (sym, 0, sizeof (unsigned long long) * WIDTH2)
#endif


#if N == 7
/* WIDTH == TWO_POW_N / (sizeof(longlong) * 8)  */
#undef WIDTH
#define WIDTH 2
#define MASK_PROTO(sym) unsigned long long *sym
#define MASK_DECL(sym) unsigned long long sym[WIDTH]
#define MASK_INV(sym) sym
#define MASK_TEST(sym,nr) \
  (!! (sym[((nr) >> 6) & (WIDTH - 1)] & (1ULL << ((nr) & 63))))
#define MASK_SET(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH - 1)] |= (1ULL << ((nr) & 63)))
#define MASK_CLEAR(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH - 1)] &= ~(1ULL << ((nr) & 63)))
#define MASK_COPY(sym1,sym2) \
  memcpy (sym1, sym2, sizeof (unsigned long long) * WIDTH)
#define MASK_RESET(sym) \
  memset (sym, 0, sizeof (unsigned long long) * WIDTH)

/* MASKBIG holds TWO_POWER_2N bits.  */
/* 2^(2*7) / 64 == 1024 ull words.  */
#define WIDTH2 256
#define MASKBIG_PROTO(sym) unsigned long long *sym
#define MASKBIG_DECL(sym) unsigned long long sym[WIDTH2]
#define MASKBIG_INV(sym) sym
#define MASKBIG_TEST(sym,nr) \
  (!! (sym[((nr) >> 6) & (WIDTH2 - 1)] & (1ULL << ((nr) & 63))))
#define MASKBIG_SET(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH2 - 1)] |= (1ULL << ((nr) & 63)))
#define MASKBIG_CLEAR(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH2 - 1)] &= ~(1ULL << ((nr) & 63)))
#define MASKBIG_COPY(sym1,sym2) \
  memcpy (sym1, sym2, sizeof (unsigned long long) * WIDTH2)
#define MASKBIG_RESET(sym) \
  memset (sym, 0, sizeof (unsigned long long) * WIDTH2)
#endif


#if N == 8
/* WIDTH == TWO_POW_N / (sizeof(longlong) * 8)  */
#undef WIDTH
#define WIDTH 4
#define MASK_PROTO(sym) unsigned long long *sym
#define MASK_DECL(sym) unsigned long long sym[WIDTH]
#define MASK_INV(sym) sym
#define MASK_TEST(sym,nr) \
  (!! (sym[((nr) >> 6) & (WIDTH - 1)] & (1ULL << ((nr) & 63))))
#define MASK_SET(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH - 1)] |= (1ULL << ((nr) & 63)))
#define MASK_CLEAR(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH - 1)] &= ~(1ULL << ((nr) & 63)))
#define MASK_COPY(sym1,sym2) \
  memcpy (sym1, sym2, sizeof (unsigned long long) * WIDTH)
#define MASK_RESET(sym) \
  memset (sym, 0, sizeof (unsigned long long) * WIDTH)

/* MASKBIG holds TWO_POWER_2N bits.  */
/* 2^(2*8) / 64 == 1024 ull words.  */
#define WIDTH2 1024
#define MASKBIG_PROTO(sym) unsigned long long *sym
#define MASKBIG_DECL(sym) unsigned long long sym[WIDTH2]
#define MASKBIG_INV(sym) sym
#define MASKBIG_TEST(sym,nr) \
  (!! (sym[((nr) >> 6) & (WIDTH2 - 1)] & (1ULL << ((nr) & 63))))
#define MASKBIG_SET(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH2 - 1)] |= (1ULL << ((nr) & 63)))
#define MASKBIG_CLEAR(sym,nr) \
  (sym[((nr) >> 6) & (WIDTH2 - 1)] &= ~(1ULL << ((nr) & 63)))
#define MASKBIG_COPY(sym1,sym2) \
  memcpy (sym1, sym2, sizeof (unsigned long long) * WIDTH2)
#define MASKBIG_RESET(sym) \
  memset (sym, 0, sizeof (unsigned long long) * WIDTH2)
#endif

