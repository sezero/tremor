/*****************************************************************************
* Copyright (c) 2012
*      MIPS Technologies, Inc., California.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
* 1. Redistributions of source code must retain the above copyright
*    notice, this list of conditions and the following disclaimer.
* 2. Redistributions in binary form must reproduce the above copyright
*    notice, this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution.
* 3. Neither the name of the MIPS Technologies, Inc., nor the names of its
*    contributors may be used to endorse or promote products derived from
*    this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE MIPS TECHNOLOGIES, INC. ``AS IS'' AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
* ARE DISCLAIMED.  IN NO EVENT SHALL THE MIPS TECHNOLOGIES, INC. BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
* OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
* HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
* LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
* OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
* SUCH DAMAGE.
*
* Author:  Nedeljko Babic (nbabic@mips.com)
*****************************************************************************/
#/***************************************************************************
#*
#*  File: decode_map.S
#*
#*  Description:
#*       basic codebook pack/unpack/code/decode operations
#*
#***************************************************************************/

#/***************************************************************************
#*
#*  Function: decode_map
#*
#*  Description:
#*       decode vector / dim granularity gaurding is done in the upper layer
#*
#*  Parameters:
#*
#*       a0      : pointer to codebook structure
#*       a1      : pointer to packet buffer
#*       a2      : vector array
#*       a3      : point
#*
#*
#*  Reference: see codebook.c
#*
#*
#*  Notes:
#*
#***************************************************************************/
   .text
   .align   2
   .globl  decode_map
   .set  nomips16
   .set  nomicromips
   .ent  decode_map
   .type decode_map, @function
   #### int decode_map(codebook *s, oggpack_buffer *b, ogg_int32_t *v,
   ####                 int point)
   # a0: codebook *s
   # a1: oggpack_buffer *b
   # a2: ogg_int32_t *v
   # a3: int point
decode_map:
   .frame $sp, 48, $ra
   .set  noreorder
   .cpload $t9
   .set  reorder
   addiu $sp, -48
   .cprestore 16
   sw    $s0, 24($sp)
   sw    $s1, 28($sp)
   sw    $s2, 32($sp)
   sw    $s3, 36($sp)
   sw    $s4, 40($sp)
   sw    $ra, 44($sp)
   move  $s1, $a0
   move  $s2, $a1
   move  $s4, $a2
   move  $s3, $a3
   jal   decode_packed_entry_number
   lw    $s0, 8($s2)                         # s0: b->headend
   move  $a3, $v0                            # a3: entry =
                                             # decode_packed_entry_number(s,b)
   .set  noreorder
   .set  nomacro
   bltz  $s0, decode_map_end                 # if(b->headend<0)return (-1);
    li   $v0, -1                             # v0: return -1
   .set  macro
   .set  reorder
   lw    $s2, 44($s1)                        # s2: s->q_pack
   lw    $t1, 28($s1)                        # t1: s->q_minp
   lw    $t0, 24($s1)                        # t0: s->q_delp
   mul   $t6, $a3, $s2                       # t6: entry*s->q_pack
   lw    $t3, 36($s1)                        # t3: s->q_min
   sub   $t1, $s3, $t1                       # t1: add = point-s->q_minp
   sub   $t0, $s3, $t0                       # t0: shiftM = point-s->q_delp
   neg   $t4, $t1                            # t4: -add
   neg   $t5, $t0                            # t5: -shiftM
   srav  $t9, $t3, $t1                       # t9: add= s->q_min >> add
   sll   $t8, $t3, $t4                       # t8: add= s->q_min << -add
   lw    $t2, 32($s1)                        # t2: mul = s->q_del
   slt   $t7, $zero, $t1                     # if(add>0)
   movz  $t9, $t8, $t7
   sllv  $t8, $t2, $t5                       # t8: mul <<= -shiftM
   slti  $t7, $t0, 0                         # if (shiftM<0)
   movn  $t2, $t8, $t7                       # mul <<= -shiftM
   movn  $t0, $zero, $t7                     # shiftM = 0
   lw    $s0, 12($s1)                        # s0: s->dec_type
   lw    $a0, 20($s1)                        # a0: s->dim
   lw    $t4, 16($s1)                        # t4: s->q_bits
   li    $t1, 1
   #### 1 used by test file 0 ####
   #### according to decode type ####
   sll   $a0, 2                              # a0: s->dim * 4
   addiu $s0, -1                             # s0: s->dec_type - 1
   sllv  $t9, $t9, $t0                       # t9: add <<= shiftM
   # switch(s->dec_type)
   .set  noreorder
   .set  nomacro
   lw    $t7, 40($s1)                        # t7: s->q_seq
   move  $s3, $s4                            # s3 -> &v[0]
   beqz  $s0, decode_map_case_1
    li   $v1, 0                              # v1: i=0
   addiu $s0, -1                             # s0: s->dec_type - 2
   slti  $t3, $t4, 9                         # if(s->q_bits<=8)
   beqz  $s0, decode_map_case_2
    lw   $t8, 48($s1)                        # t8 -> s->q_val
   addiu $s0, -1                             # s0: s->dec_type - 3
   bnez  $s0, decode_map_end                 # default case of switch statement
    li   $v0, -1
decode_map_case_3:
   #### offset into array ####
   beqz  $a0, decode_map_end_case
    nop
   beqz  $t3, decode_map_case3_else_lp       # if(s->q_bits<=8)
    add  $t8, $t6                            # void *ptr= s->q_val+
                                             #     entry*s->q_pack;
decode_map_case3_lp:
   lbu   $t5, 0($t8)                         # t5: ((unsigned char *)ptr)[i]
   addiu $t8, 1
   addiu $v1, 4                              # i++
   mul   $t5, $t2                            # t5: v[i] * mul
   add   $t5, $t9                            # t5: add + v[i] * mul
   addiu $s3, 4
   srav  $t5, $t5, $t0                       # t5:((add + v[i] * mul) >> shiftM)
   bne   $v1, $a0, decode_map_case3_lp       # for(i=0;i<s->dim;i++)
    sw   $t5, -4($s3)                        # v[i]=((unsigned char *)ptr)[i];

   b  decode_map_end_case
    nop
   # s->q_bits>8
decode_map_case3_else_lp:
   lhu   $t5, 0($t8)                         # t5: ((ogg_uint16_t *)ptr)[i]
   addiu $t8, 2
   addiu $v1, 4                              # i++
   mul   $t5, $t2                            # t5: v[i] * mul
   add   $t5, $t9                            # t5: add + v[i] * mul
   addiu $s3, 4
   srav  $t5, $t5, $t0                       # t5:((add + v[i] * mul) >> shiftM)
   bne   $v1, $a0, decode_map_case3_else_lp  # for(i=0;i<s->dim;i++)
    sw   $t5, -4($s3)                        # v[i]=((ogg_uint16_t *)ptr)[i];

   b  decode_map_end_case
    nop
decode_map_case_2:
   #### packed vector of column offsets ####
   beqz  $a0, decode_map_end_case
    sllv $t1, $t1, $s2                       # t1: 1<<s->q_pack
   beqz  $t3, decode_map_case2_else_lp       # if(s->q_bits<=8)
    addiu $t1, -1                            # t1: mask=(1<<s->q_pack)-1

decode_map_case2_lp:
   and   $t3, $a3, $t1                       # t3: entry&mask
#if __mips_dsp__
   lbux  $t5, $t3($t8)                       # t5:(unsigned char*)(s->q_val))[entry&mask]
#else
   addu  $t5,$t3,$t8
   lbu   $t5,($t5)
#endif
   srav  $a3, $a3, $s2                       # a3: entry>>=s->q_pack
   addiu $v1, 4                              # i++
   mul   $t5, $t2                            # t5: v[i] * mul
   add   $t5, $t9                            # t5: add + v[i] * mul
   addiu $s3, 4
   srav  $t5, $t5, $t0                       # t5:((add + v[i] * mul) >> shiftM)
   bne   $v1, $a0, decode_map_case2_lp
    sw   $t5, -4($s3)

   b  decode_map_end_case
    nop
   # s->q_bits>8
decode_map_case2_else_lp:
   and   $t3, $a3, $t1                       # t3: entry&mask
   sll   $t3, 1                              # t3: (entry&mask) * 2
   addu  $t5,$t3,$t8
   lhu   $t5,($t5)                           # t5:(ogg_uint16_t*)(s->q_val))[entry&mask]
   srav  $a3, $a3, $s2                       # a3: entry>>=s->q_pack
   addiu $v1, 4                              # i++
   mul   $t5, $t2                            # t5: v[i] * mul
   add   $t5, $t9                            # t5: add + v[i] * mul
   addiu $s3, 4
   srav  $t5, $t5, $t0                       # t5:((add + v[i] * mul) >> shiftM)
   bne   $v1, $a0, decode_map_case2_else_lp
    sw   $t5, -4($s3)

   b  decode_map_end_case
    nop
decode_map_case_1:
   #### packed vector of values ####
   sllv  $t1, $t1, $t4                       # t1: 1<<s->q_bits
   beqz  $a0, decode_map_end_case
    addiu $t1, -1                            # t1: mask=(1<<s->q_bits)-1

decode_map_case_1_lp:
   and   $t3, $a3, $t1                       # t3: entry&mask
   mul   $t3, $t2                            # t3: (entry&mask)*mul
   srav  $a3, $a3, $t4                       # a3: entry>>=s->q_bits
   addiu $v1, 4                              # i++
   addiu $s3, 4                              # s3 -> &v[i+1]
   add   $t5, $t9, $t3                       # add + (entry&mask) * mul
   srav  $t5, $t5, $t0                       # ((add+(entry&mask)*mul)>>shiftM)
   bne   $v1, $a0, decode_map_case_1_lp
    sw   $t5, -4($s3)                        # v[i]= ((add +
                                             #   (entry&mask) * mul) >> shiftM)
decode_map_end_case:
   beqz  $t7, decode_map_end                 # if(s->q_seq)
    li   $v0, 0                              # return 0
   addiu $a0, -4                             # a0: s->dim --
   blez  $a0, decode_map_end
    lw   $t0, 0($s4)                         # v[0]

decode_map_finall_lp:
   lw    $t1, 4($s4)                         # v[i]
   addiu $s4, 4
   addiu $a0, -4                             # s->dim - 1
   add   $t0, $t1, $t0                       # v[i]+=v[i-1]
   bnez  $a0, decode_map_finall_lp           # for(i=1;i<s->dim;i++)
    sw    $t0, 0($s4)
   .set  macro
   .set  reorder

decode_map_end:
   lw    $s0, 24($sp)
   lw    $s1, 28($sp)
   lw    $s2, 32($sp)
   lw    $s3, 36($sp)
   lw    $s4, 40($sp)
   lw    $ra, 44($sp)
   addiu $sp, 48
   jr    $ra
   .end  decode_map
#/***************************************************************************
#*
#*  Function: vorbis_book_decodevv_add
#*
#*  Description:
#*       decode residual values
#*
#*  Parameters:
#*
#*       a0     : pointer to codebook structure
#*       a1     : pointer to arrays of input buffer
#*       a2     : offset in buffers
#*       a3     : number of channels
#*              : pointer to oggpack buffer
#*              : samples per partition
#*              : -8
#*
#*
#*  Reference: see codebook.c
#*
#*
#*  Notes:
#*
#***************************************************************************/
   .text
   .align   2
   .globl  vorbis_book_decodevv_add
   .set  nomips16
   .set  nomicromips
   .ent  vorbis_book_decodevv_add
   .type vorbis_book_decodevv_add, @function
   #### long vorbis_book_decodevv_add(codebook *book,ogg_int32_t **a,
   ####                               long offset,int ch,oggpack_buffer *b,
   ####                               int n,int point)
   # a0: codebook *book
   # a1: ogg_int32_t **a
   # a2: long offset
   # a3: int ch
   # 16($sp): oggpack_buffer *b
   # 20($sp): int n
   # 24($sp): int point
vorbis_book_decodevv_add:
   .frame $sp, 64, $ra
   .set  noreorder
   .cpload $t9
   .set  reorder
   addiu $sp, -64
   lw    $t0, 52($a0)                        # t0: book->used_entries
   .cprestore 16
   sw    $s0, 24($sp)
   sw    $s1, 28($sp)
   sw    $s2, 32($sp)
   sw    $s3, 36($sp)
   sw    $s4, 40($sp)
   sll   $s2, $a2, 2                         # s2: i = offset * 4
   li    $s1, 0                              # s1: chptr = 0
   sll   $s4, $a3, 2                         # s4: ch * 4
   slt   $t1, $zero, $t0
   sw    $s5, 44($sp)
   sw    $s6, 48($sp)
   sw    $s7, 52($sp)
   sw    $s8, 56($sp)
   sw    $ra, 60($sp)
   .set  noreorder
   .set  nomacro
   beqz  $t1, vorbis_book_decodevv_add_end   # if(book->used_entries>0)
    li   $v0, 0                              # return 0
   .set  macro
   .set  reorder

   lw    $s5, 56($a0)                        # s5: ogg_int32_t *v =
                                             #           book->dec_buf;
   lw    $s7, 84($sp)                        # s7: n
   move  $s0, $a1                            # s0: a
   .set  noreorder
   .set  nomacro
   beqz  $s5, vorbis_book_decodevv_add_end   # if (!v) return -1
    li   $v0, -1                             # return -1
   .set  macro
   .set  reorder
   lw    $s3, 20($a0)                        # s3: book -> dim
   sll   $s7, 2                              # n * 4
   addu  $s7, $s2                            # s7: offset + n
   lw    $s6, 0($s0)                         # s6: &a[0][0]
   sll   $s3, 2                              # s3: (book -> dim) * 4
   add   $s6, $s2                            # s6: &a[0][offset]

   move  $s8, $a0                            # s8: book
vorbis_book_decodevv_add_i_lp:
   lw    $a1, 80($sp)                        # a1: b
   lw    $a3, 88($sp)                        # a3: point
   move  $a2, $s5                            # a2: v
   jal   decode_map                          # decode_map returns 0 or -1
   .set  noreorder
   .set  nomacro
   bnez  $v0, vorbis_book_decodevv_add_end   # if(decode_map(book,b,v,point))
                                             #     return -1
    li   $t9, 0                              # t9: j = 0

vorbis_book_decodevv_add_j_lp:
   .set  macro
   .set  reorder
   addiu $s1, 4                              # s1: chptr++
   lw    $t4, 0($s6)                         # t4: a[chptr][i]
#if __mips_dsp__
   lwx   $t0, $t9($s5)                       # t0: v[j]
#else
   addu  $t0, $t9, $s5
   lw    $t0,($t0)
#endif
   addiu $t9, 4                              # j++
   add   $t0, $t4                            # t0: a[chptr++][i]+=v[j]
   sw    $t0, 0($s6)
#if __mips_dsp__
   lwx   $s6, $s1($s0)                       # s6: &a[chptr++][i]
#else
   addu  $s6, $s1, $s0
   lw    $s6,($s6)
#endif
   bne   $s1, $s4, vorbis_book_decodevv_add_j_end
   lw    $s6, 0($s0)                         # s6: &a[0][0]
   li    $s1, 0                              # s1: chptr = 0
   addiu $s2, 4                              # s2: i++
vorbis_book_decodevv_add_j_end:
   .set  noreorder
   .set  nomacro
   bne   $t9, $s3, vorbis_book_decodevv_add_j_lp
    add  $s6, $s2                            # s6: next &a[chptr][i]
   bne   $s2, $s7, vorbis_book_decodevv_add_i_lp
    move $a0, $s8                            # a0: book
   .set  macro
   .set  reorder

vorbis_book_decodevv_add_end:
   lw    $ra, 60($sp)
   lw    $s0, 24($sp)
   lw    $s1, 28($sp)
   lw    $s2, 32($sp)
   lw    $s3, 36($sp)
   lw    $s4, 40($sp)
   lw    $s5, 44($sp)
   lw    $s6, 48($sp)
   lw    $s7, 52($sp)
   lw    $s8, 56($sp)
   addiu $sp, 64
   jr    $ra
   .end  vorbis_book_decodevv_add