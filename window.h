/********************************************************************
 *                                                                  *
 * THIS FILE IS PART OF THE OggVorbis 'TREMOR' CODEC SOURCE CODE.   *
 *                                                                  *
 * THE OggVorbis 'TREMOR' SOURCE CODE IS (C) COPYRIGHT 1994-2002    *
 * BY THE Xiph.Org FOUNDATION http://www.xiph.org/                  *
 * ALL REDISTRIBUTION RIGHTS RESERVED.                              *
 *                                                                  *
 ********************************************************************

 function: window functions

 ********************************************************************/

#ifndef _V_WINDOW_
#define _V_WINDOW_

extern ogg_int32_t *_vorbis_window(int type,int left);
extern void _vorbis_apply_window(ogg_int32_t *d,ogg_int32_t *window[2],
				 long *blocksizes,
				 int lW,int W,int nW);


#endif
