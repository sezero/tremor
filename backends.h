/********************************************************************
 *                                                                  *
 * THIS FILE IS PART OF THE OggVorbis 'TREMOR' CODEC SOURCE CODE.   *
 *                                                                  *
 * USE, DISTRIBUTION AND REPRODUCTION OF THIS LIBRARY SOURCE IS     *
 * GOVERNED BY A BSD-STYLE SOURCE LICENSE INCLUDED WITH THIS SOURCE *
 * IN 'COPYING'. PLEASE READ THESE TERMS BEFORE DISTRIBUTING.       *
 *                                                                  *
 * THE OggVorbis 'TREMOR' SOURCE CODE IS (C) COPYRIGHT 1994-2003    *
 * BY THE Xiph.Org FOUNDATION http://www.xiph.org/                  *
 *                                                                  *
 ********************************************************************

 function: backend and mapping structures

 ********************************************************************/

/* this is exposed up here because we need it for static modes.
   Lookups for each backend aren't exposed because there's no reason
   to do so */

#ifndef _vorbis_backend_h_
#define _vorbis_backend_h_

#include "codec_internal.h"

/* this would all be simpler/shorter with templates, but.... */
/* Transform backend generic *************************************/

/* only mdct right now.  Flesh it out more if we ever transcend mdct
   in the transform domain */

/* Floor backend generic *****************************************/
typedef struct{
  vorbis_info_floor     *(*unpack)(vorbis_info *,oggpack_buffer *);
  void (*free_info) (vorbis_info_floor *);
  void *(*inverse1)  (struct vorbis_block *,vorbis_look_floor *);
  int   (*inverse2)  (struct vorbis_block *,vorbis_look_floor *,
		     void *buffer,ogg_int32_t *);
} vorbis_func_floor;

typedef struct{
  int   order;
  long  rate;
  long  barkmap;

  int   ampbits;
  int   ampdB;

  int   numbooks; /* <= 16 */
  char  books[16];

} vorbis_info_floor0;

#define VIF_POSIT 63
#define VIF_CLASS 16
#define VIF_PARTS 31

typedef struct{
  char  class_dim;        /* 1 to 8 */
  char  class_subs;       /* 0,1,2,3 (bits: 1<<n poss) */
  unsigned char  class_book;       /* subs ^ dim entries */
  unsigned char  class_subbook[8]; /* [VIF_CLASS][subs] */
} floor1class;  

typedef struct{
  floor1class  *class;          /* [VIF_CLASS] */
  char         *partitionclass; /* [VIF_PARTS]; 0 to 15 */
  ogg_uint16_t *postlist;       /* [VIF_POSIT+2]; first two implicit */ 
  char         *forward_index;  /* [VIF_POSIT+2]; */
  char         *hineighbor;     /* [VIF_POSIT]; */
  char         *loneighbor;     /* [VIF_POSIT]; */

  int          partitions;    /* 0 to 31 */
  int          posts;
  int          mult;          /* 1 2 3 or 4 */ 

} vorbis_info_floor1;

/* Residue backend generic *****************************************/
typedef struct{
  vorbis_info_residue *(*unpack)(vorbis_info *,oggpack_buffer *);
  vorbis_look_residue *(*look)  (vorbis_dsp_state *,vorbis_info_mode *,
				 vorbis_info_residue *);
  void (*free_info)    (vorbis_info_residue *);
  void (*free_look)    (vorbis_look_residue *);
  int  (*inverse)      (struct vorbis_block *,vorbis_look_residue *,
			ogg_int32_t **,int *,int);
} vorbis_func_residue;

typedef struct vorbis_info_residue0{
/* block-partitioned VQ coded straight residue */
  long  begin;
  long  end;

  /* first stage (lossless partitioning) */
  int    grouping;         /* group n vectors per partition */
  int    partitions;       /* possible codebooks for a partition */
  int    groupbook;        /* huffbook for partitioning */
  int    secondstages[64]; /* expanded out to pointers in lookup */
  int    booklist[256];    /* list of second stage books */
} vorbis_info_residue0;

/* Mapping backend generic *****************************************/
typedef struct{
  vorbis_info_mapping *(*unpack)(vorbis_info *,oggpack_buffer *);
  vorbis_look_mapping *(*look)  (vorbis_dsp_state *,vorbis_info_mode *,
				 vorbis_info_mapping *);
  void (*free_info)    (vorbis_info_mapping *);
  void (*free_look)    (vorbis_look_mapping *);
  int  (*inverse)      (struct vorbis_block *vb,vorbis_look_mapping *);
} vorbis_func_mapping;

typedef struct vorbis_info_mapping0{
  int   submaps;  /* <= 16 */
  int   chmuxlist[256];   /* up to 256 channels in a Vorbis stream */
  
  int   floorsubmap[16];   /* [mux] submap to floors */
  int   residuesubmap[16]; /* [mux] submap to residue */

  int   psy[2]; /* by blocktype; impulse/padding for short,
                   transition/normal for long */

  int   coupling_steps;
  int   coupling_mag[256];
  int   coupling_ang[256];
} vorbis_info_mapping0;

#endif





