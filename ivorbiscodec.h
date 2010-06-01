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

#ifndef _vorbis_codec_h_
#define _vorbis_codec_h_

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */

#include "ogg.h"

struct vorbis_dsp_state;
typedef struct vorbis_dsp_state vorbis_dsp_state;

typedef struct vorbis_info{
  int version;
  int channels;
  long rate;

  /* The below bitrate declarations are *hints*.
     Combinations of the three values carry the following implications:
     
     all three set to the same value: 
       implies a fixed rate bitstream
     only nominal set: 
       implies a VBR stream that averages the nominal bitrate.  No hard 
       upper/lower limit
     upper and or lower set: 
       implies a VBR bitstream that obeys the bitrate limits. nominal 
       may also be set to give a nominal rate.
     none set:
       the coder does not care to speculate.
  */

  long bitrate_upper;
  long bitrate_nominal;
  long bitrate_lower;
  long bitrate_window;

  void *codec_setup;
} vorbis_info;

typedef struct vorbis_comment{
  char **user_comments;
  int   *comment_lengths;
  int    comments;
  char  *vendor;

} vorbis_comment;

/* vorbis_dsp_state buffers the current vorbis audio
   analysis/synthesis state.  The DSP state belongs to a specific
   logical bitstream ****************************************************/
struct vorbis_dsp_state{
  vorbis_info    *vi;
  oggpack_buffer  opb;

  ogg_int32_t   **work;
  ogg_int32_t   **mdctright;
  int             out_begin;
  int             out_end;

  long lW;
  long W;

  ogg_int64_t granulepos;
  ogg_int64_t sequence;
  ogg_int64_t sample_count;

};

/* Vorbis PRIMITIVES: general ***************************************/

extern void     vorbis_info_init(vorbis_info *vi);
extern void     vorbis_info_clear(vorbis_info *vi);
extern int      vorbis_info_blocksize(vorbis_info *vi,int zo);
extern void     vorbis_comment_init(vorbis_comment *vc);
extern void     vorbis_comment_add(vorbis_comment *vc, char *comment); 
extern void     vorbis_comment_add_tag(vorbis_comment *vc, 
				       char *tag, char *contents);
extern char    *vorbis_comment_query(vorbis_comment *vc, char *tag, int count);
extern int      vorbis_comment_query_count(vorbis_comment *vc, char *tag);
extern void     vorbis_comment_clear(vorbis_comment *vc);


/* Vorbis PRIMITIVES: synthesis layer *******************************/

extern vorbis_dsp_state *vorbis_dsp_create(vorbis_info *vi);
extern void     vorbis_dsp_destroy(vorbis_dsp_state *v);
extern int      vorbis_dsp_headerin(vorbis_info *vi,vorbis_comment *vc,
                                    ogg_packet *op);

extern int      vorbis_dsp_restart(vorbis_dsp_state *v);
extern int      vorbis_dsp_synthesis(vorbis_dsp_state *vd,
                                     ogg_packet *op,int decodep);
extern int      vorbis_dsp_pcmout(vorbis_dsp_state *v,
                                  ogg_int16_t *pcm,int samples);
extern int      vorbis_dsp_read(vorbis_dsp_state *v,int samples);
extern long     vorbis_packet_blocksize(vorbis_info *vi,ogg_packet *op);

/* Vorbis ERRORS and return codes ***********************************/

#define OV_FALSE      -1  
#define OV_EOF        -2
#define OV_HOLE       -3

#define OV_EREAD      -128
#define OV_EFAULT     -129
#define OV_EIMPL      -130
#define OV_EINVAL     -131
#define OV_ENOTVORBIS -132
#define OV_EBADHEADER -133
#define OV_EVERSION   -134
#define OV_ENOTAUDIO  -135
#define OV_EBADPACKET -136
#define OV_EBADLINK   -137
#define OV_ENOSEEK    -138

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif

