/********************************************************************
 *                                                                  *
 * THIS FILE IS PART OF THE OggVorbis 'TREMOR' CODEC SOURCE CODE.   *
 *                                                                  *
 * USE, DISTRIBUTION AND REPRODUCTION OF THIS LIBRARY SOURCE IS     *
 * GOVERNED BY A BSD-STYLE SOURCE LICENSE INCLUDED WITH THIS SOURCE *
 * IN 'COPYING'. PLEASE READ THESE TERMS BEFORE DISTRIBUTING.       *
 *                                                                  *
 * THE OggVorbis 'TREMOR' SOURCE CODE IS (C) COPYRIGHT 1994-2002    *
 * BY THE Xiph.Org FOUNDATION http://www.xiph.org/                  *
 *                                                                  *
 ********************************************************************

 function: miscellaneous math and prototypes

 ********************************************************************/

#ifndef _V_RANDOM_H_
#define _V_RANDOM_H_
#include "ivorbiscodec.h"
#include "os_types.h"

extern void *_vorbis_block_alloc(vorbis_block *vb,long bytes);
extern void _vorbis_block_ripcord(vorbis_block *vb);
extern void _analysis_output(char *base,int i,ogg_int32_t *v,int point,
			     int n,int bark,int dB);

#include "asm_arm.h"

#ifndef _V_WIDE_MATH
#define _V_WIDE_MATH

#include <sys/types.h>

#if BYTE_ORDER==LITTLE_ENDIAN
union magic {
  struct {
    ogg_int32_t lo;
    ogg_int32_t hi;
  } halves;
  ogg_int64_t whole;
};
#endif 

#if BYTE_ORDER==BIG_ENDIAN
union magic {
  struct {
    ogg_int32_t hi;
    ogg_int32_t lo;
  } halves;
  ogg_int64_t whole;
};
#endif

static inline ogg_int32_t MULT32(ogg_int32_t x, ogg_int32_t y) {
  union magic magic;
  magic.whole = (ogg_int64_t)x * y;
  return magic.halves.hi;
}

static inline ogg_int32_t MULT31(ogg_int32_t x, ogg_int32_t y) {
  return MULT32(x,y)<<1;
}

static inline ogg_int32_t MULT30(ogg_int32_t x, ogg_int32_t y) {
  return MULT32(x,y)<<2;
}

static inline ogg_int32_t MULT31_SHIFT15(ogg_int32_t x, ogg_int32_t y) {
  union magic magic;
  magic.whole  = (ogg_int64_t)x * y;
  return ((ogg_uint32_t)(magic.halves.lo)>>15) | ((magic.halves.hi)<<17);
}

static inline ogg_int32_t CLIP_TO_15(ogg_int32_t x) {
  int ret=x;
  ret-= ((x<=32767)-1)&(x-32767);
  ret-= ((x>=-32768)-1)&(x+32768);
  return(ret);
}

/*
 * This should be used as a memory barrier, forcing all cached values in
 * registers to wr writen back to memory.  Might or might not be beneficial
 * depending on the architecture and compiler.
 */
#define MB()

/*
 * The XPROD functions are meant to optimize the cross products found all
 * over the place in mdct.c by forcing memory operation ordering to avoid
 * unnecessary register reloads as soon as memory is being written to.
 * However this is only beneficial on CPUs with a sane number of general
 * purpose registers which exclude the Intel x86.  On Intel, better let the
 * compiler actually reload registers directly from original memory by using
 * macros.
 */

#ifdef __i386__

#define XPROD32(_a, _b, _t, _v, _x, _y)	\
  { *(_x)= MULT32(_a,_t)+MULT32(_b,_v)    ;	\
    *(_y)= MULT32(_b,_t)-MULT32(_a,_v)    ; }
#define XPROD31(_a, _b, _t, _v, _x, _y)	\
  { *(_x)=(MULT32(_a,_t)+MULT32(_b,_v))<<1;	\
    *(_y)=(MULT32(_b,_t)-MULT32(_a,_v))<<1; }
#define XNPROD31(_a, _b, _t, _v, _x, _y)	\
  { *(_x)=(MULT32(_a,_t)-MULT32(_b,_v))<<1;	\
    *(_y)=(MULT32(_b,_t)+MULT32(_a,_v))<<1; }

#else

static inline void XPROD32(ogg_int32_t  a, ogg_int32_t  b,
			   ogg_int32_t  t, ogg_int32_t  v,
			   ogg_int32_t *x, ogg_int32_t *y)
{
  *x = MULT32(a, t) + MULT32(b, v);
  *y = MULT32(b, t) - MULT32(a, v);
}

static inline void XPROD31(ogg_int32_t  a, ogg_int32_t  b,
			   ogg_int32_t  t, ogg_int32_t  v,
			   ogg_int32_t *x, ogg_int32_t *y)
{
  *x = (MULT32(a, t) + MULT32(b, v))<<1;
  *y = (MULT32(b, t) - MULT32(a, v))<<1;
}

static inline void XNPROD31(ogg_int32_t  a, ogg_int32_t  b,
			    ogg_int32_t  t, ogg_int32_t  v,
			    ogg_int32_t *x, ogg_int32_t *y)
{
  *x = (MULT32(a, t) - MULT32(b, v))<<1;
  *y = (MULT32(b, t) + MULT32(a, v))<<1;
}

#endif

#endif

static inline ogg_int32_t VFLOAT_MULT(ogg_int32_t a,ogg_int32_t ap,
				      ogg_int32_t b,ogg_int32_t bp,
				      ogg_int32_t *p){
  if(a && b){
    *p=ap+bp+32;
    return MULT32(a,b);
  }else
    return 0;
}

static inline ogg_int32_t VFLOAT_MULTI(ogg_int32_t a,ogg_int32_t ap,
				      ogg_int32_t i,
				      ogg_int32_t *p){

  int ip=_ilog(abs(i))-31;
  return VFLOAT_MULT(a,ap,i<<-ip,ip,p);
}

static inline ogg_int32_t VFLOAT_ADD(ogg_int32_t a,ogg_int32_t ap,
				      ogg_int32_t b,ogg_int32_t bp,
				      ogg_int32_t *p){

  if(!a){
    *p=bp;
    return b;
  }else if(!b){
    *p=ap;
    return a;
  }

  /* yes, this can leak a bit. */
  if(ap>bp){
    int shift=ap-bp+1;
    *p=ap+1;
    a>>=1;
    if(shift<32){
      b=(b+(1<<(shift-1)))>>shift;
    }else{
      b=0;
    }
  }else{
    int shift=bp-ap+1;
    *p=bp+1;
    b>>=1;
    if(shift<32){
      a=(a+(1<<(shift-1)))>>shift;
    }else{
      a=0;
    }
  }

  a+=b;
  if((a&0xc0000000)==0xc0000000 || 
     (a&0xc0000000)==0){
    a<<=1;
    (*p)--;
  }
  return(a);
}

#endif




