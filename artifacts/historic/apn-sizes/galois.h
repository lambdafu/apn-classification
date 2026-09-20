#include <stdint.h>
#include <assert.h>

#include "math.h"

/* Set N to 3...9.  */
/* #define N		3 */
#define TWO_POW_N	(1 << N)

typedef uint32_t gf2n_t;

/* Reverse mapping from monome exponents to polynome exponents.  */
extern gf2n_t _galois_mon_to_poly[TWO_POW_N];

/* Mapping from a polynome in bit representation to a monome
   exponent.  The index zero is undefined.  */
extern gf2n_t _galois_poly_to_mon[TWO_POW_N];


/* Initialize the galois module.  */
void galois_init (void);

static inline gf2n_t
galois_mul (gf2n_t a, gf2n_t b)
{
  gf2n_t mon_a;
  gf2n_t mon_b;
  gf2n_t res;

  /* Our tables start from x^0 = 1.  */
  if (a == 0 || b == 0)
    return 0;

  /* mon_a := log (x, a); mon_b := log (x, b);  */
  mon_a = _galois_poly_to_mon[a];
  mon_b = _galois_poly_to_mon[b];

  res = mon_a + mon_b;
  if (res >= (TWO_POW_N - 1))
    res -= (TWO_POW_N - 1);
  return _galois_mon_to_poly[res];
}


static inline gf2n_t
galois_div (gf2n_t a, gf2n_t b)
{
  gf2n_t mon_a;
  gf2n_t mon_b;

  assert (b != 0);

  /* Our tables start from x^0 = 1.  */
  if (a == 0)
    return 0;

  mon_a = _galois_poly_to_mon[a];
  mon_b = _galois_poly_to_mon[b];

  /* This could be optimized by allowing negative offsets to
     _galois_mon_to_poly.  */
  if (mon_a < mon_b)
    mon_a += (TWO_POW_N - 1);

  return _galois_mon_to_poly[mon_a - mon_b];
}


static inline gf2n_t
galois_add (gf2n_t a, gf2n_t b)
{
  return a ^ b;
}


static inline gf2n_t
galois_sub (gf2n_t a, gf2n_t b)
{
  return a ^ b;
}


static inline gf2n_t
galois_exp (gf2n_t a, int n)
{
  int s;
  int k;
  unsigned int mask;
  gf2n_t y;
  gf2n_t res;
  int i;

  /* We first reduce the exponent.  */
  if (n >= TWO_POW_N - 1)
    n = n % (TWO_POW_N - 1);

  if (n == 0)
    return 1;

  s = n;
  if (n < 0)
    n = -n;

  /* At all times: y := a^(mask).  */
  y = a;
  res = 1;
  mask = 1;
  k = msb (n);
  for (i = 0; i < k; i++)
    {
      if (n & mask)
	res = galois_mul (res, y);
      y = galois_mul (y,y);
      mask = mask << 1;
    }

  if (s < 0)
    return galois_div (1, res);
  else
    return res;
}


/* Poly: High order monomes first.  */
static inline gf2n_t
galois_eval_poly (int poly_len, gf2n_t *poly, gf2n_t val)
{
  gf2n_t res = 0;

  while (poly_len)
    {
      res = galois_add (res, *poly);
      poly_len--;
      poly++;
      if (poly_len)
	res = galois_mul (res, val);
    }

  return res;
}


/* Calculate the MSB set in DATA.  DATA is not 0.  */
static inline int
__attribute__((always_inline, const))
_galois_msb (int data)
{
  int msb;

  __asm__ ("bsr %[data], %[msb]"
           : [msb] "=r" (msb)
           : [data] "rm" (data));

  return msb + 1;
}


static inline int
__attribute__((always_inline, const))
_galois_lsb (int data)
{
  int lsb;

  __asm__ ("bsf %[data], %[lsb]"
           : [lsb] "=r" (lsb)
           : [data] "rm" (data));

  return lsb + 1;
}


static inline int
__attribute__((always_inline, const))
galois_is_pow2 (int data)
{
  return data ? (_galois_lsb (data)) == (_galois_msb (data)) : 1;
}
