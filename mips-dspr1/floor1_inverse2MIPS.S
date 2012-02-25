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
#*  File: floor1_inverse2_asm.S
#*
#*  Description:
#*       one of floor backend 1 implementation functions
#*
#***************************************************************************/

#/***************************************************************************
#*
#*  Function: floor1_inverse2
#*
#*  Description:
#*
#*  Parameters:
#*
#*       a0      : vorbis_dsp_state buffers; the current vorbis audio
#*                 analysis/synthesis state
#*       a1      : pointer to floor parameters
#*       a2      : floor mem.
#*       a3      : pointer to out pcm buffer
#*
#*
#*  Reference: see floor1.c
#*
#*
#*  Notes:
#*
#***************************************************************************/
   .text
   .align   2
   .globl  floor1_inverse2
   .set  nomips16
   .set  nomicromips
   .ent  floor1_inverse2
   .type floor1_inverse2, @function

   #### int floor1_inverse2(vorbis_dsp_state *vd,vorbis_info_floor *in,
   ####                     ogg_int32_t *fit_value,ogg_int32_t *out) ####
floor1_inverse2:
   .frame $sp, 24, $ra
   .set  noreorder
   .cpload $t9
   .set  reorder
   addiu $sp, -24
   lw    $t1, 0($a0)                         # *(vd -> vi)
   lw    $t0, 48($a0)                        # vd -> W
   lw    $t2, 28($t1)                        # ci->blocksizes
   sll   $t0, 2
   lwx   $a0, $t0($t2)                       # ci->blocksizes[vd->W]

   .set  noreorder
   .set  nomacro
   bnez  $a2, render_lines
    sra  $a0, 1                              # n=ci->blocksizes[vd->W]/2

floor1_inverse2_memset:                      # memset(out,0,sizeof(*out)*n);
   addiu $a0, -8
   sw    $zero, 0($a3)
   sw    $zero, 4($a3)
   sw    $zero, 8($a3)
   sw    $zero, 12($a3)
   sw    $zero, 16($a3)
   sw    $zero, 20($a3)
   sw    $zero, 24($a3)
   sw    $zero, 28($a3)
   bgtz  $a0, floor1_inverse2_memset
    addiu $a3, 32
   .set  macro
   .set  reorder

   addiu $sp, 24
   li    $v0, 0                              # v0: return (0)
   jr    $ra

render_lines:
   sw    $s0, 0($sp)
   sw    $s1, 4($sp)
   sw    $s2, 8($sp)
   sw    $s3, 12($sp)
   sw    $s4, 16($sp)
   sw    $s5, 20($sp)
   move  $s4, $a0                            # store n
   #### render the lines ####
   lw    $t1, 32($a1)                        # t1 = info->mult   /* 1 2 3 or 4 */
   lw    $t2, 0($a2)                         # t2 = fit_value[0]
   li    $s2, 0                              # s2: int hx=0
   srl   $v0, $t1, 1                         # v0 = info->mult / 2
   andi  $v1, $t1, 1                         # v1 = info->mult % 2
   movz  $v1, $zero, $v0
   sllv  $s5, $t2, $v0                       # s5: fit_value[0]*info->mult
   add   $t2, $s5                            # t2: fit_value[0]*info->mult
   movn  $s5, $t2, $v1                       # s5: ly = fit_value[0]*info->mult
   li    $t8, 1                              # t8: j=1
   lw    $s0, 12($a1)                        # s0: &(info->forward_index[0])
   lw    $t9, 28($a1)                        # t9: info->posts
   lbux  $t5, $t8($s0)                       # t5: int current=
                                             #      info->forward_index[j]
                                             # //(forward_index[j]>0)
   lw    $s1, 8($a1)                         # s1: &(info->postlist[0])
   li    $a1, 0                              # a1: int lx=0
   beq   $t8, $t9, floor1_inverse2_no_lp     # if (j==info->posts)

floor1_inverse2_lp:
   sll   $t5, 2                              # t5 = current * 4
   lwx   $t2, $t5($a2)                       # t2: fit_value[current]
   sra   $t5, 1                              # t5 = current * 2
   andi  $s3, $t2, 0x7FFF                    # s3: int hy=fit_value[current]&0x7fff
   addu  $s2, $t5, $s1
   lhu   $s2, ($s2)                          # s2: hx=info->postlist[current]
   .set  noreorder
   .set  nomacro
   bne   $s3, $t2, floor1_inverse2_16
    addiu $t8, 1
   .set  macro
   .set  reorder
   sllv  $t2, $s3, $v0                       # t2: hy*=info->mult
   add   $s3, $t2                            #
   movz  $s3, $t2, $v1                       # s3: hy *= info->mult
   #### inlined static void render_line(int n,int x0,int x1,int y0,
   ####                                   int y1,ogg_int32_t *d) ####
   sub   $t2, $s3, $s5                       # t2: dy = y1 - y0
   sub   $t3, $s2, $a1                       # t3: adx = x1 - x0
   absq_s.w $t4, $t2                         # t4: ady=abs(dy)
   div   $zero, $t2, $t3
   teq   $t3, $zero, 0x7
   slt   $t6, $s2, $a0                       # if(n>x1)
   movn  $a0, $s2, $t6                       # n = x1
   addiu $t5, $t3, -1                        # t5: err = adx - 1
   la    $t6, FLOOR_fromdB_LOOKUP
   sll   $s5, 2                              # y0 * 4
   sub   $a0, $a1                            # n -= x0
   .set  noreorder
   .set  nomacro
   blez  $a0, render_line_end
    add  $t6, $s5                            # t6: floor=&FLOOR_fromdB_LOOKUP[y0];
   .set  macro
   .set  reorder
   sll   $a1, 2                              # a1: x0*4
   add   $t0, $a3, $a1                       # t0: d += x0
   mflo  $t1                                 # t1: base =dy/adx;
   mul   $t7, $t3, $t1                       # t7: base*adx
   sll   $t1, 2                              # base * 4
   absq_s.w $t7, $t7                         # abs(base*adx);
   .set  noreorder
   .set  nomacro
   bgez  $t2, render_line_lp_start           # if (dy < 0)
    sub  $t4, $t7                            # ady-=abs(base*adx);
   .set  macro
   .set  reorder
   addiu $t1, -4                             # (base * 4)--
   sub   $t4, $t3, $t4                       # ady = adx-ady
   li    $t5, 0                              # err = 0

   # one lap unrolled to fill up the stalls
render_line_lp_start:
   lw    $t2, 0($t0)                         # t2: *d
   lw    $t7, 0($t6)                         # t7: *floor
   addiu $a0, -1
   addiu $t0, 4                              # d++
   mult  $t2, $t7                            # MULT32(*d,*floor)
   .set  noreorder
   .set  nomacro
   beqz  $a0, render_line_lp_end
    add  $t6, $t1                            # floor += base
   .set  macro
   .set  reorder
render_line_lp:
   sub   $t5, $t4                            # err -= ady
   lw    $t2, 0($t0)                         # t2: *d
   addiu $t0, 4                              # d++
   .set  noreorder
   .set  nomacro
   bgez  $t5, render_line_err
    extr.w $s5, $ac0, 15                     # MULT31_SHIFT15(*d,*floor);
   .set  macro
   .set  reorder
   add   $t5, $t3                            # err += adx
   addiu $t6, 4                              # floor += 1
render_line_err:
   lw    $t7, 0($t6)                         # t7: *floor
   add   $t6, $t1                            # floor += base
   addiu $a0, -1                             # n--
   mult  $t2, $t7                            # MULT32(*d,*floor)
   .set  noreorder
   .set  nomacro
   bgtz  $a0, render_line_lp
    sw    $s5, -8($t0)
render_line_lp_end:
   sub   $t5, $t4                            # err -= ady
   bgez  $t5, render_line_err_1
    extr.w $s5, $ac0, 15                     # MULT31_SHIFT15(*d,*floor);
   .set  macro
   .set  reorder
   add   $t5, $t3                            # err += adx
   addiu $t6, 4                              # floor += 1
render_line_err_1:
   sw    $s5, -4($t0)

render_line_end:
   move  $a0, $s4                            # a0 = n
   move  $a1, $s2                            # lx = hx
   move  $s5, $s3                            # ly = hy
floor1_inverse2_16:
   .set  noreorder
   .set  nomacro
   bne   $t8, $t9, floor1_inverse2_lp        # for(j=1;j<info->posts;j++)
    lbux $t5, $t8($s0)                       # t5: int current=
                                             #        info->forward_index[j]

floor1_inverse2_no_lp:
   move  $s0, $a3                            # s0: &out[0]
   beq   $s2, $a0, floor1_inverse2_end
    li   $v0, 1
   sll   $s2, 2                              # hx*4
   sll   $a0, 2                              # n * 4
   addu  $s0, $s2                            # s0: &out[hx]

floor1_inverse2_lp2:
   lw    $t0, 0($s0)                         # out[j]
   addiu $s0, 4
   mul   $t0, $s5                            # out[j]*=ly /* be certain */
   addiu $s2, 4
   bne   $s2, $a0, floor1_inverse2_lp2       # for(j=hx;j<n;j++)
    sw    $t0, -4($s0)
   .set  macro
   .set  reorder

floor1_inverse2_end:
   lw    $s0, 0($sp)
   lw    $s1, 4($sp)
   lw    $s2, 8($sp)
   lw    $s3, 12($sp)
   lw    $s4, 16($sp)
   lw    $s5, 20($sp)
   addiu $sp, 24
   jr    $ra
   .end  floor1_inverse2