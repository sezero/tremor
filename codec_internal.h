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

 function: libvorbis codec headers

 ********************************************************************/

#ifndef _V_CODECI_H_
#define _V_CODECI_H_

#include "codebook.h"

#define VI_TRANSFORMB 1
#define VI_WINDOWB 1
#define VI_TIMEB 1
#define VI_FLOORB 2
#define VI_RESB 3
#define VI_MAPB 1

typedef void vorbis_info_floor;
typedef void vorbis_info_mapping;

/* Floor backend generic *****************************************/
typedef struct{
  vorbis_info_floor     *(*unpack)(vorbis_info *,oggpack_buffer *);
  void (*free_info) (vorbis_info_floor *);
  void *(*inverse1)  (struct vorbis_block *,vorbis_info_floor *);
  int   (*inverse2)  (struct vorbis_block *,vorbis_info_floor *,
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

typedef struct vorbis_info_residue{
  int type;
  unsigned char *stagemasks;
  unsigned char *stagebooks;

/* block-partitioned VQ coded straight residue */
  long begin;
  long end;

  /* first stage (lossless partitioning) */
  int           grouping;         /* group n vectors per partition */
  char          partitions;       /* possible codebooks for a partition */
  unsigned char groupbook;        /* huffbook for partitioning */
  char          stages;
} vorbis_info_residue;

extern void res_clear_info(vorbis_info_residue *info);
extern int res_unpack(vorbis_info_residue *info,
		      vorbis_info *vi,oggpack_buffer *opb);
extern int res_inverse(vorbis_block *vb,vorbis_info_residue *info,
		       ogg_int32_t **in,int *nonzero,int ch);

/* mode ************************************************************/
typedef struct {
  int blockflag;
  int mapping;
} vorbis_info_mode;

/* Mapping backend generic *****************************************/

typedef void vorbis_look_mapping;

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

typedef struct private_state {
  /* local lookup storage */
  const void             *window[2];

  /* backend lookups are tied to the mode, not the backend or naked mapping */
  int                     modebits;
  vorbis_look_mapping   **mode;

  ogg_int64_t sample_count;

} private_state;

/* codec_setup_info contains all the setup information specific to the
   specific compression/decompression mode in progress (eg,
   psychoacoustic settings, channel setup, options, codebook
   etc).  
*********************************************************************/

typedef struct codec_setup_info {

  /* Vorbis supports only short and long blocks, but allows the
     encoder to choose the sizes */

  long blocksizes[2];

  /* modes are the primary means of supporting on-the-fly different
     blocksizes, different channel mappings (LR or M/A),
     different residue backends, etc.  Each mode consists of a
     blocksize flag and a mapping (along with the mapping setup */

  int        modes;
  int        maps;
  int        floors;
  int        residues;
  int        books;

  vorbis_info_mode       *mode_param;
  vorbis_info_mapping    *map_param[64];
  char                   *floor_type;
  vorbis_info_floor     **floor_param;
  vorbis_info_residue    *residue_param;
  codebook               *book_param;

} codec_setup_info;

extern vorbis_func_floor     *_floor_P[];
extern vorbis_func_mapping   *_mapping_P[];

#endif
