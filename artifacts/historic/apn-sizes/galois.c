#include <stdio.h>

#include "galois.h"

/* The irreducible polynome in bit representation is IRRED_OVERRUN and
   IRRED_REDUX.  */
#if N == 1
/* x + 1 == 0 */
#define IRRED_OVERRUN	0x2
#define IRRED_REDUX	0x1
#else
#if N == 2
/* x^2 + x + 1 == 0 */
#define IRRED_OVERRUN	0x4
#define IRRED_REDUX	0x3
#else
#if N == 3
/* x^3 + x + 1 == 0 */
#define IRRED_OVERRUN	0x8
#define IRRED_REDUX	0x3
#else
#if N == 4
/* x^4 + x + 1 == 0 */
#define IRRED_OVERRUN	0x10
#define IRRED_REDUX	0x03
#else
#if N == 5
/* x^5 + x^2 + 1 == 0 */
#define IRRED_OVERRUN	0x20
#define IRRED_REDUX	0x05
#else
#if N == 6
/* x^6 + x + 1 == 0 */
#define IRRED_OVERRUN	0x40
#define IRRED_REDUX	0x03
#else
#if N == 7
/* x^7 + x + 1 == 0 */
#define IRRED_OVERRUN	0x80
#define IRRED_REDUX	0x03
#else
#if N == 8
/* x^8 + x^4 + x^3 + x^2 + 1 == 0 */
#define IRRED_OVERRUN	0x100
#define IRRED_REDUX	0x01d
#else
#if N == 9
/* x^9 + x^4 + 1 == 0 */
#define IRRED_OVERRUN	0x200
#define IRRED_REDUX	0x011
#else
#error Undefined N.
#endif
#endif
#endif
#endif
#endif
#endif
#endif
#endif
#endif

/* Reverse mapping from monome exponents to polynome exponents.  */
gf2n_t _galois_mon_to_poly[TWO_POW_N];

/* Mapping from a polynome in bit representation to a monome
   exponent.  The index zero is undefined.  */
gf2n_t _galois_poly_to_mon[TWO_POW_N];


/* Initialize the galois module.  */
void
galois_init (void)
{
  gf2n_t i;
  gf2n_t polynome;

  /* polynome := x^0;  */
  polynome = 1;
  for (i = 0; i < TWO_POW_N - 1; i++)
    {
      _galois_mon_to_poly[i] = polynome;
      _galois_poly_to_mon[polynome] = i;

      /* polynome := (polynome * x);  */
      polynome = polynome << 1;
      if (polynome & IRRED_OVERRUN)
	{
	  /* polynome := polynome - (IRRED_OVERRUN + IRRED_REDUX);  */
	  polynome = polynome & (~IRRED_OVERRUN);
	  polynome = polynome ^ IRRED_REDUX;
	}
    }
}
