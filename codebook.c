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

 function: basic codebook pack/unpack/code/decode operations

 ********************************************************************/

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "ogg.h"
#include "ivorbiscodec.h"
#include "codebook.h"
#include "misc.h"
#include "os.h"

/**** pack/unpack helpers ******************************************/
int _ilog(unsigned int v){
  int ret=0;
  while(v){
    ret++;
    v>>=1;
  }
  return(ret);
}

/* 32 bit float (not IEEE; nonnormalized mantissa +
   biased exponent) : neeeeeee eeemmmmm mmmmmmmm mmmmmmmm 
   Why not IEEE?  It's just not that important here. */

static ogg_int32_t _float32_unpack(long val,int *point){
  long   mant=val&0x1fffff;
  int    sign=val&0x80000000;
  long   exp =((val&0x7fe00000L)>>21)-788;

  if(mant){
    while(!(mant&0x40000000)){
      mant<<=1;
      exp-=1;
    }
    if(sign)mant= -mant;
  }else{
    sign=0;
    exp=-9999;
  }

  *point=exp;
  return mant;
}

/* given a list of word lengths, generate a list of codewords.  Works
   for length ordered or unordered, always assigns the lowest valued
   codewords first.  Extended to handle unused entries (length 0) */
int _make_words(char *l,long n,ogg_uint32_t *r){
  long i,j,count=0;
  ogg_uint32_t marker[33];
  memset(marker,0,sizeof(marker));

  for(i=0;i<n;i++){
    long length=l[i];
    if(length){
      ogg_uint32_t entry=marker[length];
      if(count && !entry)return -1; /* overpopulated tree! */
      r[count++]=entry;
      
      /* Look to see if the next shorter marker points to the node
	 above. if so, update it and repeat.  */
      for(j=length;j>0;j--){          
	if(marker[j]&1){
	  marker[j]=marker[j-1]<<1;
	  break;
	}
	marker[j]++;
      }
      
      /* prune the tree; the implicit invariant says all the longer
	 markers were dangling from our just-taken node.  Dangle them
	 from our *new* node. */
      for(j=length+1;j<33;j++)
	if((marker[j]>>1) == entry){
	  entry=marker[j];
	  marker[j]=marker[j-1]<<1;
	}else
	  break;
    }
  }
  
  /* bitreverse the words because our bitwise packer/unpacker is LSb
     endian */
  for(i=0,count=0;i<n;i++){
    ogg_uint32_t temp=0;
    for(j=0;j<l[i];j++){
      temp<<=1;
      temp|=(r[count]>>j)&1;
    }
    
    if(l[i])
      r[count++]=temp;
  }
  
  return 0;
}


/* most of the time, entries%dimensions == 0, but we need to be
   well defined.  We define that the possible vales at each
   scalar is values == entries/dim.  If entries%dim != 0, we'll
   have 'too few' values (values*dim<entries), which means that
   we'll have 'left over' entries; left over entries use zeroed
   values (and are wasted).  So don't generate codebooks like
   that */
/* there might be a straightforward one-line way to do the below
   that's portable and totally safe against roundoff, but I haven't
   thought of it.  Therefore, we opt on the side of caution */
long _book_maptype1_quantvals(codebook *b){
  /* get us a starting hint, we'll polish it below */
  int bits=_ilog(b->entries);
  int vals=b->entries>>((bits-1)*(b->dim-1)/b->dim);

  while(1){
    long acc=1;
    long acc1=1;
    int i;
    for(i=0;i<b->dim;i++){
      acc*=vals;
      acc1*=vals+1;
    }
    if(acc<=b->entries && acc1>b->entries){
      return(vals);
    }else{
      if(acc>b->entries){
        vals--;
      }else{
        vals++;
      }
    }
  }
}

void vorbis_book_clear(codebook *b){
  /* static book is not cleared; we're likely called on the lookup and
     the static codebook belongs to the info struct */
  if(b->valuelist)_ogg_free(b->valuelist);
  if(b->codelist)_ogg_free(b->codelist);

  if(b->dec_index)_ogg_free(b->dec_index);
  if(b->dec_codelengths)_ogg_free(b->dec_codelengths);
  if(b->dec_firsttable)_ogg_free(b->dec_firsttable);

  memset(b,0,sizeof(*b));
}

static ogg_uint32_t bitreverse(ogg_uint32_t x){
  x=    ((x>>16)&0x0000ffffUL) | ((x<<16)&0xffff0000UL);
  x=    ((x>> 8)&0x00ff00ffUL) | ((x<< 8)&0xff00ff00UL);
  x=    ((x>> 4)&0x0f0f0f0fUL) | ((x<< 4)&0xf0f0f0f0UL);
  x=    ((x>> 2)&0x33333333UL) | ((x<< 2)&0xccccccccUL);
  return((x>> 1)&0x55555555UL) | ((x<< 1)&0xaaaaaaaaUL);
}

static int sort32a(const void *a,const void *b){
  return (**(ogg_uint32_t **)a>**(ogg_uint32_t **)b)-
    (**(ogg_uint32_t **)a<**(ogg_uint32_t **)b);
}

int vorbis_book_unpack(oggpack_buffer *opb,codebook *s){
  char    *lengthlist=NULL;
  int      quantvals=0;
  long    *quantlist=NULL;
  int     *sortindex;
  long     i,j,k;

  memset(s,0,sizeof(*s));

  /* make sure alignment is correct */
  if(oggpack_read(opb,24)!=0x564342)goto _eofout;

  /* first the basic parameters */
  s->dim=oggpack_read(opb,16);
  s->entries=oggpack_read(opb,24);
  if(s->entries==-1)goto _eofout;

  /* codeword ordering.... length ordered or unordered? */
  switch((int)oggpack_read(opb,1)){
  case 0:
    /* unordered */
    lengthlist=(char *)alloca(sizeof(*lengthlist)*s->entries);

    /* allocated but unused entries? */
    if(oggpack_read(opb,1)){
      /* yes, unused entries */

      for(i=0;i<s->entries;i++){
	if(oggpack_read(opb,1)){
	  long num=oggpack_read(opb,5);
	  if(num==-1)goto _eofout;
	  lengthlist[i]=num+1;
	  s->used_entries++;
	}else
	  lengthlist[i]=0;
      }
    }else{
      /* all entries used; no tagging */
      s->used_entries=s->entries;
      for(i=0;i<s->entries;i++){
	long num=oggpack_read(opb,5);
	if(num==-1)goto _eofout;
	lengthlist[i]=num+1;
      }
    }
    
    break;
  case 1:
    /* ordered */
    {
      long length=oggpack_read(opb,5)+1;

      s->used_entries=s->entries;
      lengthlist=(char *)alloca(sizeof(*lengthlist)*s->entries);
      
      for(i=0;i<s->entries;){
	long num=oggpack_read(opb,_ilog(s->entries-i));
	if(num==-1)goto _eofout;
	for(j=0;j<num && i<s->entries;j++,i++)
	  lengthlist[i]=length;
	length++;
      }
    }
    break;
  default:
    /* EOF */
    return(-1);
  }

  {
    /* perform codebook sort */
    ogg_uint32_t *codes=(ogg_uint32_t *)alloca(s->used_entries*sizeof(*codes));
    ogg_uint32_t **codep=(ogg_uint32_t **)alloca(sizeof(*codep)*s->used_entries);
    if(_make_words(lengthlist,s->entries,codes)) goto _errout;
    
    for(i=0;i<s->used_entries;i++){
      codes[i]=bitreverse(codes[i]);
      codep[i]=codes+i;
    }
    
    qsort(codep,s->used_entries,sizeof(*codep),sort32a);
    
    sortindex=(int *)alloca(s->used_entries*sizeof(*sortindex));
    s->codelist=(ogg_uint32_t *)_ogg_malloc(s->used_entries*sizeof(*s->codelist));
    /* the index is a reverse index */
    for(i=0;i<s->used_entries;i++){
      int position=codep[i]-codes;
      sortindex[position]=i;
    }
    
    for(i=0;i<s->used_entries;i++)
      s->codelist[sortindex[i]]=codes[i];
  }
  
  /* Do we have a mapping to unpack? */
  switch((s->maptype=oggpack_read(opb,4))){
  case 0:
    /* no mapping */
    break;
  case 1: case 2:
    {
      int        *rp=(int *)alloca(s->used_entries*s->dim*sizeof(*rp));
      int         minpoint,delpoint,count=0;
      ogg_int32_t mindel=_float32_unpack(oggpack_read(opb,32),&minpoint);
      ogg_int32_t delta =_float32_unpack(oggpack_read(opb,32),&delpoint);
      int         q_quant=oggpack_read(opb,4)+1;
      int         q_sequencep=oggpack_read(opb,1);

      switch(s->maptype){
      case 1:
	quantvals=_book_maptype1_quantvals(s);
	break;
      case 2:
	quantvals=s->entries*s->dim;
	break;
      }
      
      /* quantized values */
      quantlist=(long *)alloca(sizeof(*quantlist)*quantvals);
      for(i=0;i<quantvals;i++)
	quantlist[i]=oggpack_read(opb,q_quant);
      
      if(quantvals && quantlist[quantvals-1]==-1)goto _eofout;
      s->binarypoint=minpoint;
      s->valuelist=(ogg_int32_t *)_ogg_calloc(s->used_entries*s->dim,
					      sizeof(*s->valuelist));
      
      /* maptype 1 and 2 both use a quantized value vector, but
	 different sizes */
      switch(s->maptype){
      case 1:
	for(j=0;j<s->entries;j++){
	  if(lengthlist[j]){
	    ogg_int32_t last=0;
	    int lastpoint=0;
	    int indexdiv=1;
	    for(k=0;k<s->dim;k++){
	      int index= (j/indexdiv)%quantvals;
	      int point;
	      int val=VFLOAT_MULTI(delta,delpoint,
				   abs(quantlist[index]),&point);
	      
	      val=VFLOAT_ADD(mindel,minpoint,val,point,&point);
	      val=VFLOAT_ADD(last,lastpoint,val,point,&point);
	      
	      if(q_sequencep){
		last=val;   
		lastpoint=point;
	      }
	      
	      s->valuelist[sortindex[count]*s->dim+k]=val;
              rp[sortindex[count]*s->dim+k]=point;
	      if(s->binarypoint<point)s->binarypoint=point;
	      indexdiv*=quantvals;
	    }
	    count++;
	  }
	  
	}
	break;
      case 2:
	for(j=0;j<s->entries;j++){
	  if(lengthlist[j]){
	    ogg_int32_t last=0;
	    int         lastpoint=0;
	    
	    for(k=0;k<s->dim;k++){
	      int point;
	      int val=VFLOAT_MULTI(delta,delpoint,
				   abs(quantlist[j*s->dim+k]),&point);
	      
	      val=VFLOAT_ADD(mindel,minpoint,val,point,&point);
	      val=VFLOAT_ADD(last,lastpoint,val,point,&point);
	      
	      if(q_sequencep){
		last=val;   
		lastpoint=point;
	      }
	      
	      s->valuelist[sortindex[count]*s->dim+k]=val;
              rp[sortindex[count]*s->dim+k]=point;
	      if(s->binarypoint<point)s->binarypoint=point;
	    }
	    count++;
	  }
	}
	break;
      }
      
      for(j=0;j<s->used_entries*s->dim;j++)
	if(rp[j]<s->binarypoint)
	  s->valuelist[j]>>=s->binarypoint-rp[j];
    }
    break;
  default:
    goto _errout;
  }

  /* decode side optimization lookups */
  {
    int n,tabn;
    long lo=0,hi=0;
    ogg_uint32_t mask;

    s->dec_index=(int *)_ogg_malloc(s->used_entries*sizeof(*s->dec_index));
    
    for(n=0,i=0;i<s->entries;i++)
      if(lengthlist[i]>0)
	s->dec_index[sortindex[n++]]=i;
    
    s->dec_codelengths=(char *)_ogg_malloc(n*sizeof(*s->dec_codelengths));
    for(n=0,i=0;i<s->entries;i++)
      if(lengthlist[i]>0)
	s->dec_codelengths[sortindex[n++]]=lengthlist[i];
    
    s->dec_firsttablen=_ilog(s->used_entries)-4; /* this is magic */
    if(s->dec_firsttablen<5)s->dec_firsttablen=5;
    if(s->dec_firsttablen>8)s->dec_firsttablen=8;
    
    tabn=1<<s->dec_firsttablen;
    s->dec_firsttable=
      (ogg_uint32_t *)_ogg_calloc(tabn,sizeof(*s->dec_firsttable));
    s->dec_maxlength=0;
    
    for(i=0;i<n;i++){
      if(s->dec_maxlength<s->dec_codelengths[i])
	s->dec_maxlength=s->dec_codelengths[i];
      if(s->dec_codelengths[i]<=s->dec_firsttablen){
	ogg_uint32_t orig=bitreverse(s->codelist[i]);
	for(j=0;j<(1<<(s->dec_firsttablen-s->dec_codelengths[i]));j++)
	  s->dec_firsttable[orig|(j<<s->dec_codelengths[i])]=i+1;
      }
    }
  
    /* now fill in 'unused' entries in the firsttable with hi/lo search
       hints for the non-direct-hits */

    mask=0xfffffffeUL<<(31-s->dec_firsttablen);
    
    for(i=0;i<tabn;i++){
      ogg_uint32_t word=i<<(32-s->dec_firsttablen);
      if(s->dec_firsttable[bitreverse(word)]==0){
        while((lo+1)<n && s->codelist[lo+1]<=word)lo++;
        while(    hi<n && word>=(s->codelist[hi]&mask))hi++;
        
        /* we only actually have 15 bits per hint to play with here.
           In order to overflow gracefully (nothing breaks, efficiency
           just drops), encode as the difference from the extremes. */
        {
          unsigned long loval=lo;
          unsigned long hival=n-hi;
	  
          if(loval>0x7fff)loval=0x7fff;
          if(hival>0x7fff)hival=0x7fff;
          s->dec_firsttable[bitreverse(word)]=
            0x80000000UL | (loval<<15) | hival;
        }
      }
    }
  }
  
  return 0;
 _errout:
 _eofout:
  vorbis_book_clear(s);
  return -1;
}

static inline long decode_packed_entry_number(codebook *book, 
					      oggpack_buffer *b){
  int  read=book->dec_maxlength;
  long lo,hi;
  long lok = oggpack_look(b,book->dec_firsttablen);
 
  if (lok >= 0) {
    long entry = book->dec_firsttable[lok];
    if(entry&0x80000000UL){
      lo=(entry>>15)&0x7fff;
      hi=book->used_entries-(entry&0x7fff);
    }else{
      oggpack_adv(b, book->dec_codelengths[entry-1]);
      return(entry-1);
    }
  }else{
    lo=0;
    hi=book->used_entries;
  }

  lok = oggpack_look(b, read);

  while(lok<0 && read>1)
    lok = oggpack_look(b, --read);
  if(lok<0)return -1;

  /* bisect search for the codeword in the ordered list */
  {
    ogg_uint32_t testword=bitreverse((ogg_uint32_t)lok);

    while(hi-lo>1){
      long p=(hi-lo)>>1;
      long test=book->codelist[lo+p]>testword;    
      lo+=p&(test-1);
      hi-=p&(-test);
    }

    if(book->dec_codelengths[lo]<=read){
      oggpack_adv(b, book->dec_codelengths[lo]);
      return(lo);
    }
  }
  
  oggpack_adv(b, read);
  return(-1);
}

/* Decode side is specced and easier, because we don't need to find
   matches using different criteria; we simply read and map.  There are
   two things we need to do 'depending':
   
   We may need to support interleave.  We don't really, but it's
   convenient to do it here rather than rebuild the vector later.

   Cascades may be additive or multiplicitive; this is not inherent in
   the codebook, but set in the code using the codebook.  Like
   interleaving, it's easiest to do it here.  
   addmul==0 -> declarative (set the value)
   addmul==1 -> additive
   addmul==2 -> multiplicitive */

/* returns the [original, not compacted] entry number or -1 on eof *********/
long vorbis_book_decode(codebook *book, oggpack_buffer *b){
  long packed_entry=decode_packed_entry_number(book,b);
  if(packed_entry>=0)
    return(book->dec_index[packed_entry]);
  
  /* if there's no dec_index, the codebook unpacking isn't collapsed */
  return(packed_entry);
}

/* returns 0 on OK or -1 on eof *************************************/
long vorbis_book_decodevs_add(codebook *book,ogg_int32_t *a,
			      oggpack_buffer *b,int n,int point){
  int step=n/book->dim;
  long *entry = (long *)alloca(sizeof(*entry)*step);
  ogg_int32_t **t = (ogg_int32_t **)alloca(sizeof(*t)*step);
  int i,j,o;
  int shift=point-book->binarypoint;

  if(shift>=0){
    for (i = 0; i < step; i++) {
      entry[i]=decode_packed_entry_number(book,b);
      if(entry[i]==-1)return(-1);
      t[i] = book->valuelist+entry[i]*book->dim;
    }
    for(i=0,o=0;i<book->dim;i++,o+=step)
      for (j=0;j<step;j++)
	a[o+j]+=t[j][i]>>shift;
  }else{
    for (i = 0; i < step; i++) {
      entry[i]=decode_packed_entry_number(book,b);
      if(entry[i]==-1)return(-1);
      t[i] = book->valuelist+entry[i]*book->dim;
    }
    for(i=0,o=0;i<book->dim;i++,o+=step)
      for (j=0;j<step;j++)
	a[o+j]+=t[j][i]<<-shift;
  }
  return(0);
}

long vorbis_book_decodev_add(codebook *book,ogg_int32_t *a,
			     oggpack_buffer *b,int n,int point){
  int i,j,entry;
  ogg_int32_t *t;
  int shift=point-book->binarypoint;
  
  if(shift>=0){
    for(i=0;i<n;){
      entry = decode_packed_entry_number(book,b);
      if(entry==-1)return(-1);
      t     = book->valuelist+entry*book->dim;
      for (j=0;j<book->dim;)
	a[i++]+=t[j++]>>shift;
    }
  }else{
    for(i=0;i<n;){
      entry = decode_packed_entry_number(book,b);
      if(entry==-1)return(-1);
      t     = book->valuelist+entry*book->dim;
      for (j=0;j<book->dim;)
	a[i++]+=t[j++]<<-shift;
    }
  }
  return(0);
}

long vorbis_book_decodev_set(codebook *book,ogg_int32_t *a,
			     oggpack_buffer *b,int n,int point){
  int i,j,entry;
  ogg_int32_t *t;
  int shift=point-book->binarypoint;
  
  if(shift>=0){

    for(i=0;i<n;){
      entry = decode_packed_entry_number(book,b);
      if(entry==-1)return(-1);
      t     = book->valuelist+entry*book->dim;
      for (j=0;j<book->dim;){
	a[i++]=t[j++]>>shift;
      }
    }
  }else{

    for(i=0;i<n;){
      entry = decode_packed_entry_number(book,b);
      if(entry==-1)return(-1);
      t     = book->valuelist+entry*book->dim;
      for (j=0;j<book->dim;){
	a[i++]=t[j++]<<-shift;
      }
    }
  }
  return(0);
}

long vorbis_book_decodevv_add(codebook *book,ogg_int32_t **a,\
			      long offset,int ch,
			      oggpack_buffer *b,int n,int point){
  long i,j,entry;
  int chptr=0;
  int shift=point-book->binarypoint;
  
  if(shift>=0){
    
    for(i=offset;i<offset+n;){
      entry = decode_packed_entry_number(book,b);
      if(entry==-1)return(-1);
      {
	const ogg_int32_t *t = book->valuelist+entry*book->dim;
	for (j=0;j<book->dim;j++){
	  a[chptr++][i]+=t[j]>>shift;
	  if(chptr==ch){
	    chptr=0;
	    i++;
	  }
	}
      }
    }
  }else{

    for(i=offset;i<offset+n;){
      entry = decode_packed_entry_number(book,b);
      if(entry==-1)return(-1);
      {
	const ogg_int32_t *t = book->valuelist+entry*book->dim;
	for (j=0;j<book->dim;j++){
	  a[chptr++][i]+=t[j]<<-shift;
	  if(chptr==ch){
	    chptr=0;
	    i++;
	  }
	}
      }
    }
  }
  return(0);
}
