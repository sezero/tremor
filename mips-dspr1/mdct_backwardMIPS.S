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
#*  File: mdct_backward.S
#*
#*  Description:
#*
#***************************************************************************/

#/***************************************************************************
#*
#*  Function: mdct_backward
#*
#*  Parameters:
#*
#*       a0      : number of subbands (sblimit)
#*       a1      : pointer to granule
#*
#*
#*  Reference: see mdct.c
#*
#*
#*  Notes:
#*       partial; doesn't perform last-step deinterleave/unrolling.  That
#*       can be done more efficiently during pcm output
#*
#***************************************************************************/
#ifdef _LOW_ACCURACY_
#define cPI3_8 (0x0062)
#define cPI2_8 (0x00b5)
#define cPI1_8 (0x00ed)
#else
#define cPI3_8 (0x30fbc54d)
#define cPI2_8 (0x5a82799a)
#define cPI1_8 (0x7641af3d)
#endif

#******************************** mdct_backward ********************
   .text
   .align   2
   .globl  mdct_backward
   .set  nomips16
   .set  nomicromips
   .ent  mdct_backward
   .type mdct_backward, @function
   #### void mdct_backward(int n, DATA_TYPE *in) ####
   # a0 = n
   # a1 = &in
mdct_backward:
   .frame $sp, 56, $ra
   .set  noreorder
   .cpload $t9
   .set  reorder

   addiu $sp, -56
   li    $a3, -1
   li    $t0, 4                              # t0: shift = 4
   sw    $a0, 56($sp)                        # n
   sw    $a1, 60($sp)                        # &in
   sw    $s0, 16($sp)
   sw    $s1, 20($sp)
   sw    $s2, 24($sp)
   sw    $s5, 36($sp)
   sw    $s6, 40($sp)
   sw    $s7, 44($sp)
   sw    $s8, 48($sp)
   sw    $ra, 52($sp)
   sll   $ra, $a0, 1                         # ra: (points >> i) * 4
   sw    $s3, 28($sp)
   sw    $s4, 32($sp)
   li    $t1, 1

mdct_backward_shift:
   sllv  $t3, $t1, $t0                       # 1<<shift
   and   $t3, $t3, $a0                       # (n&(1<<shift))
   .set  noreorder
   .set  nomacro
   beqz  $t3, mdct_backward_shift            # for (shift=4;!(n&(1<<shift));
                                             #        shift++)
    addiu $t0, 1                             # shift++
   .set  macro
   .set  reorder

   addiu $t0, -1                             # t0: shift
   li    $t1, 13                             # t1: 13
   sub   $t0, $t1, $t0                       # shift=13-shift;
   li    $t1, 2
   sllv  $a2, $t1, $t0                       # a2: step=2<<shift
   sw    $t0, 0($sp)                         # shift

#******************************** presymmetry ********************
   addu  $t9, $a1, $a0                       # t9 = in + n/4
   sll   $a0, 1                              # a0: (n/2)*4
   addu  $s1, $a1, $a0
   addiu $s1, -3*4                           # s1: aX = in + n2 - 3
   la    $s0, sincos_lookup0                 # s0: T = sincos_lookup0
   sw    $a2, 4($sp)
   sll   $a2, 2                              # step * 4

   lw    $t3, 0($s1)                         # t3: r0= aX[0];
   lw    $t0, 0($s0)                         # t0: T[0]
   lw    $t2, 2*4($s1)                       # t2: r2= aX[2];
   lw    $t1, 4($s0)                         # t1: T[1]
   # XPROD31( r0, r2, T[0], T[1], &aX[0], &aX[2] );
   # pipeline warm-up before loop
   mult  $t3, $t0                            # MULT32(r0, T[0])
   mtlo  $zero
   madd  $t2, $t1                            # MULT32(r0, T[0]) +
                                             #     MULT32(r2, T[1])
   addiu $s1, -4*4                           # aX -= 4
presymmetry_lp1:
   add   $s0, $a2                            # T += step
   slt   $t8, $s1, $t9                       # (aX>=in+n4);
   mfhi  $t5
   mult  $t2, $t0                            # MULT32(r2, T[0])
   mtlo  $a3
   msub  $t3, $t1                            # MULT32(r2, T[0]) -
                                             #     MULT32(r0, T[1])
   lw    $t3, 0($s1)                         # t3: r0= aX[0];
   lw    $t0, 0($s0)                         # t0: T[0]
   lw    $t2, 2*4($s1)                       # t2: r2= aX[2];
   sll   $t5, 1                              # (MULT32(r0,T[0]) +
                                             #     MULT32(r2,T[1]))<<1
   mfhi  $t6
   sw    $t5, 4*4($s1)                       # aX[0] = (MULT32(r0, T[0]) +
                                             #           MULT32(r2, T[1]))<<1
   lw    $t1, 4($s0)                         # t1: T[1]
   # XPROD31( r0, r2, T[0], T[1], &aX[0], &aX[2] );
   mult  $t3, $t0                            # MULT32(r0, T[0])
   mtlo  $zero
   addiu $s1, -4*4                           # aX -= 4
   madd  $t2, $t1                            # MULT32(r0, T[0]) +
                                             #     MULT32(r2, T[1])
   sll   $t6, 1                              # (MULT32(r2,T[0]) -
                                             #     MULT32(r0,T[1])) << 1
   .set  noreorder
   .set  nomacro
   beqz  $t8, presymmetry_lp1                # while(aX>=in+n4);
    sw   $t6, 4*10($s1)                      # aX[2] = (MULT32(r2, T[0]) -
                                             #           MULT32(r0, T[1]))<<1

   # pipeline warm-up before loop
   lw    $t3, 4*4($s1)                       # t3: r0= aX[0];
   lw    $t0, 4($s0)                         # t0: T[1]
   lw    $t2, 6*4($s1)                       # t2: r2= aX[2];
   lw    $t1, 0($s0)                         # t1: T[0]
   # XPROD31( r0, r2, T[1], T[0], &aX[0], &aX[2] );
   mult  $t3, $t0                            # MULT32(r0, T[1])
   mtlo  $zero
   madd  $t2, $t1                            # MULT32(r0, T[1]) +
                                             #        MULT32(r2, T[0])
presymmetry_lp2:
   sub   $s0, $a2                            # T -= step
   slt   $t8, $s1, $a1                       # (aX>=in);
   mfhi  $t5
   mult  $t2, $t0                            # MULT32(r2, T[1])
   mtlo  $a3
   msub  $t3, $t1                            # MULT32(r2, T[1]) -
                                             #     MULT32(r0, T[0])
   lw    $t3, 0($s1)                         # t3: r0= aX[0];
   lw    $t0, 4($s0)                         # t0: T[1]
   lw    $t2, 2*4($s1)                       # t2: r2= aX[2];
   sll   $t5, 1                              # (MULT32(r0, T[1]) +
                                             #     MULT32(r2, T[0]))<<1
   mfhi  $t6
   sw    $t5, 4*4($s1)                       # aX[0] = (MULT32(r0, T[1]) +
                                             #           MULT32(r2, T[0]))<<1
   lw    $t1, 0($s0)                         # t1: T[0]
   # XPROD31( r0, r2, T[1], T[0], &aX[0], &aX[2] );
   mult  $t3, $t0                            # MULT32(r0, T[1])
   mtlo  $zero
   addiu $s1, -4*4                           # aX -= 4
   madd  $t2, $t1                            # MULT32(r0, T[1]) +
                                             #     MULT32(r2, T[0])
   sll   $t6, 1                              # (MULT32(r2, T[1]) -
                                             #     MULT32(r0, T[0])) << 1
   beqz  $t8, presymmetry_lp2                # while(aX>=in)
    sw   $t6, 4*10($s1)                      # aX[2] = (MULT32(r2, T[1]) -
                                             #           MULT32(r0, T[0]))<<1
   .set  macro
   .set  reorder

   addu  $s1, $a1, $a0                       #
   addiu $s1, -4*4                           # s1: aX = in + n2 - 4
   move  $s2, $a1                            # s2: bX = in
   la    $s0, sincos_lookup0                 # s0: T = sincos_lookup0

   # pipeline warm-up before loop
   lw    $v0, 0($s2)                         # v0: ro0= bX[0];
   lw    $v1, 8($s2)                         # v1: ro2= bX[2];
   lw    $t0, 0($s0)                         # t0 = T[0]
   lw    $t1, 4($s0)                         # t1 = T[1]
   lw    $t3, 0($s1)                         # t3: ri0= aX[0];
   lw    $t2, 8($s1)                         # t2: ri2= aX[2];
   # XNPROD31( ro2, ro0, T[1], T[0], &aX[0], &aX[2] )
   mult  $v1, $t1                            # MULT32(ro2, T[1])
   mtlo  $a3
   msub  $v0, $t0                            # MULT32(ro2, T[1]) -
                                             #     MULT32(ro0, T[0])
   addu  $s0, $a2                            # T += step
presymmetry_lp3:
   addiu $s1, -4*4                           # aX -= 4
   addiu $s2, 4*4                            # bX += 4
   lw    $t7, 0($s0)                         # t7 = T[0]
   mfhi  $t5
   mult  $v0, $t1                            # MULT32(ro0, T[1])
   mtlo  $zero
   madd  $v1, $t0                            # MULT32(ro0, T[1]) +
                                             #     MULT32(ro2, T[0])
   slt   $t8, $s1, $s2                       # (aX>=bX);
   lw    $t4, 4($s0)                         # t4 = T[1]
   lw    $v0, 0($s2)                         # v0: ro0= bX[0];
   lw    $v1, 8($s2)                         # v1: ro2= bX[2];
   mfhi  $t6
   # XNPROD31( ri2, ri0, T[0], T[1], &bX[0], &bX[2] )
   mult  $t2, $t7                            # MULT32(ri2, T[0])
   mtlo  $a3
   msub  $t3, $t4                            # MULT32(ri2, T[0]) -
                                             #    MULT32(ri0, T[1])
   sll   $t5, 1                              # (MULT32(ro2, T[1]) -
                                             #     MULT32(ro0, T[0]))<<1
   sw    $t5, 4*4($s1)                       # aX[0] = (MULT32(ro2, T[1]) -
                                             #              MULT32(ro0, T[0]))<<1
   lw    $t0, 0($s0)                         # t0 = T[0]
   sll   $t6, 1                              # (MULT32(ro0, T[1]) +
                                             #     MULT32(ro2, T[0]))<<1
   mfhi  $t5
   mult  $t3, $t7                            # MULT32(ri0, T[0])
   mtlo  $zero
   madd  $t2, $t4                            # MULT32(ri2, T[0]) +
                                             #     MULT32(ri0, T[1])
   sw    $t6, 6*4($s1)                       # aX[2] = (MULT32(ro0, T[1]) +
                                             #     MULT32(ro2, T[0]))<<1
   lw    $t1, 4($s0)                         # t1 = T[1]
   lw    $t3, 0($s1)                         # t3: ri0= aX[0];
   sll   $t5, 1                              # (MULT32(ri2, T[0]) -
                                             #     MULT32(ri0, T[1]))<<1
   mfhi  $t6
   sw    $t5, -4*4($s2)                      # bX[0] = (MULT32(ri2, T[0]) -
                                             #           MULT32(ri0, T[1]))<<1
   lw    $t2, 8($s1)                         # t2: ri2= aX[2];
   # XNPROD31( ro2, ro0, T[1], T[0], &aX[0], &aX[2] )
   mult  $v1, $t1                            # MULT32(ro2, T[1])
   mtlo  $a3
   msub  $v0, $t0                            # MULT32(ro2, T[1]) -
                                             #     MULT32(ro0, T[0])
   addu  $s0, $a2                            # T += step
   sll   $t6, 1                              # (MULT32(ri0, T[0]) +
                                             #     MULT32(ri2, T[1]))<<1
   .set  noreorder
   .set  nomacro
   beqz  $t8, presymmetry_lp3                # while(aX>=bX);
    sw   $t6, -2*4($s2)                      # bX[2] = (MULT32(ri0, T[0]) +
                                             #           MULT32(ri2, T[1]))<<1

#******************************** mdct_butterflies ********************
   lw    $a2, 0($sp)                         # a2: shift
   li    $t0, 6
   sub   $s5, $t0, $a2                       # s5: --stages=6-shift;
   bltz  $s5, mdct_butterfly_32
    li   $s6, 0                              # s6: i = 0
   .set  macro
   .set  reorder
   addiu $s5, 1                              # to simplify for loop test
   li    $s7, 0                              # s7: j = 0
   li    $s8, 1                              # s8: 1<<i

mdct_butterflies_lp_1:
   lw    $t2, 0($sp)                         # t2: shift
   move  $a0, $ra                            # a0: (points>>i) * 4
   addu  $t0, $a1, $ra                       # x+(points>>i)*(j+1)*4
   sw    $t0, 8($sp)
   li    $a2, 16                             # a2: 4 * 4
   add   $t2, $s6                            # t2: i+shift

mdct_butterflies_lp_2:
   sllv  $a2, $a2, $t2                       # a2: 4 * 4 << (i + shift)
   # from this point variable names from mdct_butterfly_generic
   addu  $s1, $a1, $a0                       # s1: x1 = x + points
   sra   $a0, 1                              # a0: (points * 4) >> 1
   addiu $s1, -4*4                           # x + points - 4
   addu  $s2, $a1, $a0                       # s2: x + (points >> 1)
   addiu $s2, -4*4                           # s2: x2 = x + (points >> 1) - 4
   la    $s0, sincos_lookup0                 # s0: LOOKUP_T *T  = sincos_lookup0;
   move  $t8, $a2                            # counter
   slti  $t9, $a2, 4*1024
   # pipeline warm-up before loop
   lw    $t0, 0($s1)                         # t0: x1[0]
   lw    $t2, 8($s1)                         # t2: x1[2]
   .set  noreorder
   .set  nomacro
   beqz  $t9, mdct_butterfly_generic_lp1_end	# jump if only one iteration
    lw   $t1, 4($s1)                         # t1: x1[1]

mdct_butterfly_generic_lp1:
   lw    $t3, 12($s1)                        # t3: x1[3]
   lw    $v0, 0($s0)                         # v0: T[0]
   lw    $v1, 4($s0)                         # v1: T[1]
   sub   $s4, $t3, $t2                       # s4: r1 = x1[3] - x1[2];
   sub   $s3, $t0, $t1                       # s3: r0 = x1[0] - x1[1];
   # XPROD31( r1, r0, T[0], T[1], &x2[0], &x2[2] );
   mult  $s4, $v0                            # MULT32(r1, T[0])
   mtlo  $zero
   madd  $s3, $v1                            # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))
   add   $t0, $t1                            # x1[0] += x1[1];
   lw    $t4, 0($s2)                         # t4: x2[0]
   lw    $t5, 4($s2)                         # t5: x2[1]
   lw    $t6, 8($s2)                         # t6: x2[2]
   mfhi  $t1
   mult  $s3, $v0                            # MULT32(r0, T[0])
   mtlo  $a3
   msub  $s4, $v1                            # (MULT32(r0,T[0]) -
                                             #     MULT32(r1,T[1]))
   lw    $t7, 12($s2)                        # t7: x2[3]
   sub   $s3, $t5, $t4                       # s3: r2 = x2[1] - x2[0];
   sub   $s4, $t7, $t6                       # s4: r3 = x2[3] - x2[2];
   sll   $t1, 1                              # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))<<1
   sw    $t1, 0($s2)
   add   $t2, $t3                            # x1[2] += x1[3];
   mfhi  $t3
   # XPROD31( r2, r3, T[0], T[1], &x2[1], &x2[3] );
   mult  $s3, $v0                            # MULT32(r2, T[0])
   mtlo  $zero
   madd  $s4, $v1                            # (MULT32(r2,T[0]) +
                                             #     MULT32(r3,T[1]))
   add   $t5, $t4                            # x1[1]  = x2[1] + x2[0];
   add   $t6, $t7                            # x1[3]  = x2[3] + x2[2];
   sw    $t0, 0($s1)
   sll   $t3, 1                              # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))<<1
   sw    $t3, 8($s2)
   sw    $t2, 8($s1)
   mfhi  $t1
   mult  $s4, $v0                            # MULT32(r3, T[0])
   mtlo  $a3
   msub  $s3, $v1                            # (MULT32(r3,T[0]) -
                                             #     MULT32(r2,T[1]))
   sw    $t5, 4($s1)
   sw    $t6, 12($s1)
   addu  $t8, $a2                            # counter += 4* step
   sll   $t1, 1                              # (MULT32(r2,T[0]) +
                                             #     MULT32(r3,T[1]))<<1
   sw    $t1, 4($s2)
   slti  $t9, $t8, 4 * 1024                  # while(T<sincos_lookup0+1024);
   mfhi  $t3
   addiu $s1, -4*4                           # x1 -= 4;
   addu  $s0, $a2                            # T += step;
   addiu $s2, -4*4                           # x2 -= 4;
   lw    $t0, 0($s1)                         # t0: x1[0]
   lw    $t2, 8($s1)                         # t2: x1[2]
   lw    $t1, 4($s1)                         # t1: x1[1]
   sll   $t3, 1                              # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))<<1
   bnez  $t9,  mdct_butterfly_generic_lp1
    sw   $t3, 7*4($s2)
   .set  macro
   .set  reorder

   # pipeline drained after mdct_butterfly_generic_lp1
mdct_butterfly_generic_lp1_end:
   lw    $t3, 12($s1)                        # t3: x1[3]
   lw    $v0, 0($s0)                         # v0: T[0]
   lw    $v1, 4($s0)                         # v1: T[1]
   sub   $s4, $t3, $t2                       # s4: r1 = x1[3] - x1[2];
   sub   $s3, $t0, $t1                       # s3: r0 = x1[0] - x1[1];
   # XPROD31( r1, r0, T[0], T[1], &x2[0], &x2[2] );
   mult  $s4, $v0                            # MULT32(r1, T[0])
   mtlo  $zero
   madd  $s3, $v1                            # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))
   add   $t0, $t1                            # x1[0] += x1[1];
   lw    $t4, 0($s2)                         # t4: x2[0]
   lw    $t5, 4($s2)                         # t5: x2[1]
   lw    $t6, 8($s2)                         # t6: x2[2]
   mfhi  $t1
   mult  $s3, $v0                            # MULT32(r0, T[0])
   mtlo  $a3
   msub  $s4, $v1                            # (MULT32(r0,T[0]) -
                                             #     MULT32(r1,T[1]))
   lw    $t7, 12($s2)                        # t7: x2[3]
   sub   $s3, $t5, $t4                       # s3: r2 = x2[1] - x2[0];
   sub   $s4, $t7, $t6                       # s4: r3 = x2[3] - x2[2];
   sll   $t1, 1                              # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))<<1
   sw    $t1, 0($s2)
   add   $t2, $t3                            # x1[2] += x1[3];
   mfhi  $t3
   # XPROD31( r2, r3, T[0], T[1], &x2[1], &x2[3] );
   mult  $s3, $v0                            # MULT32(r2, T[0])
   mtlo  $zero
   madd  $s4, $v1                            # (MULT32(r2,T[0]) +
                                             #     MULT32(r3,T[1]))
   add   $t5, $t4                            # x1[1]  = x2[1] + x2[0];
   add   $t6, $t7                            # x1[3]  = x2[3] + x2[2];
   sw    $t0, 0($s1)
   sll   $t3, 1                              # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))<<1
   sw    $t3, 8($s2)
   sw    $t2, 8($s1)
   mfhi  $t1
   mult  $s4, $v0                            # MULT32(r3, T[0])
   mtlo  $a3
   msub  $s3, $v1                            # (MULT32(r3,T[0]) -
                                             #     MULT32(r2,T[1]))
   sw    $t5, 4($s1)
   sw    $t6, 12($s1)
   sra   $t0, $a0, 1                         # t0: (points>>2)
   sll   $t1, 1                              # (MULT32(r2,T[0]) +
                                             #     MULT32(r3,T[1]))<<1
   sw    $t1, 4($s2)
   mfhi  $t3
   addiu $s1, -4*4                           # x1 = x + (points>>1) - 4
   addiu $s2, -4*4                           # x2 -= 4;
   addu  $s0, $a2                            # T += step;
   move  $t8, $a2                            # counter
   slti  $t9, $a2, 4*1024
   sll   $t3, 1                              # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))<<1
   sw    $t3, 7*4($s2)

   # pipeline warm-up before loop
   lw    $t0, 0($s1)                         # t0: x1[0]
   lw    $t2, 8($s1)                         # t2: x1[2]
   .set  noreorder
   .set  nomacro
   beqz  $t9, mdct_butterfly_generic_lp2_end	# jump if only one iteration
    lw   $t1, 4($s1)                         # t1: x1[1]

mdct_butterfly_generic_lp2:
   lw    $t3, 12($s1)                        # t3: x1[3]
   lw    $v0, 0($s0)                         # v0: T[0]
   lw    $v1, 4($s0)                         # v1: T[1]
   sub   $s3, $t0, $t1                       # s3: r0 = x1[0] - x1[1];
   sub   $s4, $t2, $t3                       # s4: r1 = x1[2] - x1[3];
   # XNPROD31( r0, r1, T[0], T[1], &x2[0], &x2[2] );
   mult  $s3, $v0                            # MULT32(r0, T[0])
   mtlo  $a3
   msub  $s4, $v1                            # (MULT32(r0,T[0]) -
                                             #     MULT32(r1,T[1]))
   add   $t0, $t1                            # x1[0] += x1[1];
   lw    $t4, 0($s2)                         # t4: x2[0]
   lw    $t5, 4($s2)                         # t5: x2[1]
   lw    $t6, 8($s2)                         # t6: x2[2]
   mfhi  $t1
   mult  $s4, $v0                            # MULT32(r1, T[0])
   mtlo  $zero
   madd  $s3, $v1                            # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))
   lw    $t7, 12($s2)                        # t7: x2[3]
   add   $t2, $t3                            # x1[2] += x1[3];
   sub   $s4, $t7, $t6                       # s4: r3 = x2[3] - x2[2];
   sll   $t1, 1                              # (MULT32(r0,T[0]) -
                                             #     MULT32(r1,T[1]))<<1
   sw    $t1, 0($s2)
   sub   $s3, $t4, $t5                       # s3: r2 = x2[0] - x2[1];
   mfhi  $t3
   # XNPROD31( r3, r2, T[0], T[1], &x2[1], &x2[3] );
   mult  $s4, $v0                            # MULT32(r3, T[0])
   mtlo  $a3
   msub  $s3, $v1                            # (MULT32(r3,T[0]) -
                                             #     MULT32(r2,T[1]))
   add   $t5, $t4                            # x1[1]  = x2[1] + x2[0];
   add   $t6, $t7                            # x1[3]  = x2[3] + x2[2];
   sw    $t0, 0($s1)
   sll   $t3, 1                              # (MULT32(r1,T[0]) -
                                             #     MULT32(r0,T[1]))<<1
   sw    $t3, 8($s2)
   sw    $t2, 8($s1)
   mfhi  $t1
   mult  $s3, $v0                            # MULT32(r2, T[0])
   mtlo  $zero
   madd  $s4, $v1                            # (MULT32(r2,T[0]) +
                                             #     MULT32(r3,T[1]))
   sw    $t5, 4($s1)
   sw    $t6, 12($s1)
   addu  $t8, $a2                            # counter += 4* step
   sll   $t1, 1                              # (MULT32(r3,T[0]) -
                                             #     MULT32(r2,T[1]))<<1
   sw    $t1, 4($s2)
   slti  $t9, $t8, 4 * 1024                  # while(T<sincos_lookup0);
   mfhi  $t3
   sub   $s0, $a2                            # T -= step;
   addiu $s1, -4*4                           # x1 -= 4;
   addiu $s2, -4*4                           # x2 -= 4;
   lw    $t0, 0($s1)                         # t0: x1[0]
   lw    $t2, 8($s1)                         # t2: x1[2]
   lw    $t1, 4($s1)                         # t1: x1[1]
   sll   $t3, 1                              # (MULT32(r2,T[0]) +
                                             #     MULT32(r3,T[1]))<<1
   bnez  $t9,  mdct_butterfly_generic_lp2
    sw   $t3, 7*4($s2)

   # pipeline drained after mdct_butterfly_generic_lp2
mdct_butterfly_generic_lp2_end:
   lw    $t3, 12($s1)                        # t3: x1[3]
   lw    $v0, 0($s0)                         # v0: T[0]
   lw    $v1, 4($s0)                         # v1: T[1]
   sub   $s3, $t0, $t1                       # s3: r0 = x1[0] - x1[1];
   sub   $s4, $t2, $t3                       # s4: r1 = x1[2] - x1[3];
   # XNPROD31( r0, r1, T[0], T[1], &x2[0], &x2[2] );
   mult  $s3, $v0                            # MULT32(r0, T[0])
   mtlo  $a3
   msub  $s4, $v1                            # (MULT32(r0,T[0]) -
                                             #     MULT32(r1,T[1]))
   add   $t0, $t1                            # x1[0] += x1[1];
   lw    $t4, 0($s2)                         # t4: x2[0]
   lw    $t5, 4($s2)                         # t5: x2[1]
   lw    $t6, 8($s2)                         # t6: x2[2]
   mfhi  $t1
   mult  $s4, $v0                            # MULT32(r1, T[0])
   mtlo  $zero
   madd  $s3, $v1                            # (MULT32(r1,T[0]) +
                                             #     MULT32(r0,T[1]))
   lw    $t7, 12($s2)                        # t7: x2[3]
   add   $t2, $t3                            # x1[2] += x1[3];
   sub   $s4, $t7, $t6                       # s4: r3 = x2[3] - x2[2];
   sll   $t1, 1                              # (MULT32(r0,T[0]) -
                                             #     MULT32(r1,T[1]))<<1
   sw    $t1, 0($s2)
   sub   $s3, $t4, $t5                       # s3: r2 = x2[0] - x2[1];
   mfhi  $t3
   # XNPROD31( r3, r2, T[0], T[1], &x2[1], &x2[3] );
   mult  $s4, $v0                            # MULT32(r3, T[0])
   mtlo  $a3
   msub  $s3, $v1                            # (MULT32(r3,T[0]) -
                                             #     MULT32(r2,T[1]))
   add   $t5, $t4                            # x1[1]  = x2[1] + x2[0];
   add   $t6, $t7                            # x1[3]  = x2[3] + x2[2];
   sw    $t0, 0($s1)
   sll   $t3, 1                              # (MULT32(r1,T[0]) -
                                             #     MULT32(r0,T[1]))<<1
   sw    $t3, 8($s2)
   sw    $t2, 8($s1)
   mfhi  $t1
   mult  $s3, $v0                            # MULT32(r2, T[0])
   mtlo  $zero
   madd  $s4, $v1                            # (MULT32(r2,T[0]) +
                                             #     MULT32(r3,T[1]))
   sw    $t5, 4($s1)
   sw    $t6, 12($s1)
   lw    $a1, 8($sp)                         # a1: x+(points>>i)*j
   sll   $t1, 1                              # (MULT32(r3,T[0]) -
                                             #     MULT32(r2,T[1]))<<1
   sw    $t1, 4($s2)
   lw    $t2, 0($sp)                         # t2: shift
   mfhi  $t3
   move  $a0, $ra                            # a0: (points>>i)
   addu  $t0, $a1, $ra                       # x+(points>>i)*(j+1)
   sw    $t0, 8($sp)
   li    $a2, 16                             # a2: 4 * 4
   add   $t2, $s6                            # t2: i+shift
   addiu $s7, 1                              # s7: j++
   sll   $t3, 1                              # (MULT32(r2,T[0]) +
                                             #     MULT32(r3,T[1]))<<1
   bne   $s7, $s8, mdct_butterflies_lp_2     # for(j=0;j<(1<<i);j++)
    sw   $t3, 3*4($s2)

   lw    $a1, 60($sp)                        # a1: x
   addiu $s6, 1                              # i++
   sll   $s8, 1                              # s8: 1<<i
   sra   $ra, 1                              # ra: points >> i
   bne   $s5, $s6, mdct_butterflies_lp_1     # for(i=0;--stages>=0;i++)
    li   $s7, 0                              # s7: j = 0
   .set  macro
   .set  reorder

   #### 32 point butterfly (in place, 4 register) ####
   #### STIN void mdct_butterfly_32(DATA_TYPE *x) ####
mdct_butterfly_32:
   lw    $a0, 56($sp)                        # a0: points
   li    $s0, cPI3_8
   sra   $a0, 1
   li    $s1, cPI1_8
   li    $s2, cPI2_8
   beqz  $a0, mdct_butterfly_32_end

mdct_butterfly_32_lp:
   lw    $t8, 16*4($a1)                      # t8: x[16]
   lw    $t9, 17*4($a1)                      # t9: x[17]
   lw    $v0, 18*4($a1)                      # v0: x[18]
   lw    $v1, 19*4($a1)                      # v1: x[19]
   sub   $t0, $t8, $t9                       # t0: r0 = x[16] - x[17]
   sub   $t1, $v0, $v1                       # t1: r1 = x[18] - x[19]
   # XNPROD31( r0, r1, cPI3_8, cPI1_8, &x[ 0], &x[ 2] );
   mult  $t0, $s0                            # MULT32(r0, cPI3_8)
   mtlo  $a3
   msub  $t1, $s1                            # MULT32(r0, cPI3_8) -
                                             #     MULT32(r1, cPI1_8)
   lw    $t4, 0($a1)                         # t4: x[0]
   lw    $t5, 4($a1)                         # t5: x[1]
   lw    $t6, 2*4($a1)                       # t6: x[2]
   lw    $t7, 3*4($a1)                       # t7: x[3]
   mfhi  $s3
   mult  $t1, $s0                            # MULT32(r1, cPI3_8)
   mtlo  $zero
   madd  $t0, $s1                            # MULT32(r1, cPI3_8) +
                                             #     MULT32(r0, cPI1_8)
   sub   $t2, $t5, $t4                       # t2: r2 = x[1] - x[0]
   sub   $t3, $t7, $t6                       # t3: r3 = x[3] - x[2]
   add   $t8, $t9                            # x[16] += x[17]
   sll   $s3, 1                              # (MULT32(r0, cPI3_8) -
                                             #     MULT32(r1, cPI1_8)) << 1
   sw    $s3, 0($a1)
   add   $v0, $v1                            # x[18] += x[19]
   mfhi  $s4
   # XPROD31 ( r2, r3, cPI1_8, cPI3_8, &x[ 1], &x[ 3] );
   mult  $t2, $s1                            # MULT32(r2, cPI1_8)
   mtlo  $zero
   madd  $t3, $s0                            # MULT32(r2, cPI1_8) +
                                             #     MULT32(r3, cPI3_8)
   add   $t9, $t5, $t4                       # x[17]  = x[ 1] + x[ 0]
   add   $v1, $t7, $t6                       # x[19]  = x[ 3] + x[ 2]
   sw    $t8, 16*4($a1)                      # t8: x[16]
   sll   $s4, 1                              # (MULT32(r0, cPI3_8) -
                                             #     MULT32(r1, cPI1_8)) << 1
   sw    $s4, 2*4($a1)
   sw    $t9, 17*4($a1)                      # t9: x[17]
   mfhi  $t0
   mult  $t3, $s1                            # MULT32(r3, cPI1_8)
   mtlo  $a3
   msub  $t2, $s0                            # MULT32(r3, cPI1_8) -
                                             #     MULT32(r2, cPI3_8)
   sw    $v0, 18*4($a1)                      # v0: x[18]
   sw    $v1, 19*4($a1)                      # v1: x[19]
   lw    $t8, 20*4($a1)                      # t8: x[20]
   sll   $t0, 1                              # (MULT32(r2, cPI1_8) +
                                             #     MULT32(r3, cPI3_8)) << 1
   sw    $t0, 4($a1)
   lw    $t9, 21*4($a1)                      # t9: x[21]
   mfhi  $s4
   lw    $v0, 22*4($a1)                      # v0: x[22]
   lw    $v1, 23*4($a1)                      # v1: x[23]
   sub   $t0, $t8, $t9                       # t0: r0 = x[20] - x[21]
   lw    $t4, 4*4($a1)                       # t4: x[4]
   sub   $t1, $v0, $v1                       # t1: r1 = x[22] - x[23]
   sub   $s3, $t0, $t1                       # s3: r0 - r1
   sll   $s4, 1                              # (MULT32(r3, cPI1_8) -
                                             #     MULT32(r2, cPI3_8)) << 1
   sw    $s4, 3*4($a1)
   lw    $t5, 5*4($a1)                       # t5: x[5]
   lw    $t6, 6*4($a1)                       # t6: x[6]
   lw    $t7, 7*4($a1)                       # t7: x[7]
   mult  $s3, $s2                            # MULT32((r0-r1), cPI2_8)
   add   $t8, $t9                            # x[20] += x[21]
   add   $v0, $v1                            # x[22] += x[23]
   sub   $t2, $t5, $t4                       # t2: r2 = x[5] - x[4]
   sub   $t3, $t7, $t6                       # t3: r3 = x[7] - x[6]
   mfhi  $s3
   add   $s4, $t2, $t3                       # s4: r3 + r2
   mult  $s4, $s2                            # MULT32((r3+r2), cPI2_8)
   add   $t9, $t5, $t4                       # x[21]  = x[ 5] + x[ 4]
   add   $v1, $t7, $t6                       # x[23]  = x[ 7] + x[ 6]
   add   $t0, $t1                            # t0: r0 + r1
   sub   $t3, $t2                            # t3: r3 - r2
   mfhi  $s4
   mult  $t0, $s2                            # MULT32((r0+r1), cPI2_8)
   sll   $s3, 1                              # MULT31((r0-r1), cPI2_8)
   sw    $s3, 4*4($a1)                       # x[ 4] = MULT31((r0 - r1) , cPI2_8)
   sw    $t8, 20*4($a1)                      # t8: x[20]
   sw    $t9, 21*4($a1)                      # t9: x[21]
   mfhi  $s3
   mult  $t3, $s2                            # MULT32((r3-r2), cPI2_8)
   sll   $s4, 1                              # MULT31((r3+r2), cPI2_8)
   sw    $s4, 5*4($a1)                       # x[ 5] = MULT31((r3 + r2) , cPI2_8)
   sw    $v0, 22*4($a1)                      # v0: x[22]
   sw    $v1, 23*4($a1)                      # v1: x[23]
   mfhi  $s4
   sll   $s3, 1                              # MULT31((r0+r1), cPI2_8)
   sw    $s3, 6*4($a1)                       # x[ 6] = MULT31((r0 + r1) , cPI2_8)
   lw    $t8, 24*4($a1)                      # t8: x[24]
   lw    $t9, 25*4($a1)                      # t9: x[25]
   lw    $v0, 26*4($a1)                      # v0: x[26]
   lw    $v1, 27*4($a1)                      # v1: x[27]
   sll   $s4, 1                              # MULT31((r3-r2), cPI2_8)
   sw    $s4, 7*4($a1)                       # x[ 7] = MULT31((r3 - r2) , cPI2_8)
   lw    $t4, 8*4($a1)                       # t4: x[8]
   lw    $t5, 9*4($a1)                       # t5: x[9]
   lw    $t6, 10*4($a1)                      # t6: x[10]
   lw    $t7, 11*4($a1)                      # t7: x[11]
   sub   $t0, $t8, $t9                       # t0: r0 = x[24] - x[25]
   sub   $t1, $v0, $v1                       # t1: r1 = x[26] - x[27]
   sub   $t2, $t5, $t4                       # t2: r2 = x[9] - x[8]
   sub   $t3, $t7, $t6                       # t3: r3 = x[11] - x[10]
   add   $t8, $t9                            # x[24] += x[25]
   add   $v0, $v1                            # x[26] += x[27]
   add   $t9, $t5, $t4                       # x[25]  = x[ 9] + x[ 8]
   add   $v1, $t7, $t6                       # x[27]  = x[ 11] + x[ 10]
   sw    $t8, 24*4($a1)                      # t8: x[24]
   sw    $t9, 25*4($a1)                      # t9: x[25]
   sw    $v0, 26*4($a1)                      # v0: x[26]
   sw    $v1, 27*4($a1)                      # v1: x[27]
   # XNPROD31( r0, r1, cPI1_8, cPI3_8, &x[ 8], &x[ 10] );
   mult  $t0, $s1                            # MULT32(r0, cPI1_8)
   mtlo  $a3
   msub  $t1, $s0                            # MULT32(r0, cPI1_8) -
                                             #     MULT32(r1, cPI3_8)
   lw    $t8, 28*4($a1)                      # t8: x[28]
   lw    $t9, 29*4($a1)                      # t9: x[29]
   lw    $v0, 30*4($a1)                      # v0: x[30]
   lw    $v1, 31*4($a1)                      # v1: x[31]
   mfhi  $s3
   mult  $t1, $s1                            # MULT32(r1, cPI1_8)
   mtlo  $zero
   madd  $t0, $s0                            # MULT32(r1, cPI1_8) +
                                             #     MULT32(r0, cPI3_8)
   lw    $t4, 12*4($a1)                      # t4: x[12]
   lw    $t5, 13*4($a1)                      # t5: x[13]
   lw    $t6, 14*4($a1)                      # t6: x[14]
   sll   $s3, 1                              # (MULT32(r0, cPI1_8) -
                                             #     MULT32(r1, cPI3_8)) << 1
   mfhi  $s4
   # XPROD31 ( r2, r3, cPI3_8, cPI1_8, &x[ 9], &x[ 11] );
   mult  $t2, $s0                            # MULT32(r2, cPI3_8)
   mtlo  $zero
   madd  $t3, $s1                            # MULT32(r2, cPI3_8) +
                                             #     MULT32(r3, cPI1_8)
   sw    $s3, 8*4($a1)
   lw    $t7, 15*4($a1)                      # t7: x[15]
   sub   $t0, $t8, $t9                       # t0: r0 = x[28] - x[29]
   sll   $s4, 1                              # (MULT32(r1, cPI1_8) +
                                             #     MULT32(r0, cPI3_8)) << 1
   mfhi  $s3
   mult  $t3, $s0                            # MULT32(r3, cPI3_8)
   mtlo  $a3
   msub  $t2, $s1                            # MULT32(r3, cPI3_8) -
                                             #     MULT32(r2, cPI1_8)
   sw    $s4, 10*4($a1)
   sub   $t1, $v0, $v1                       # t1: r1 = x[30] - x[31]
   sub   $t2, $t4, $t5                       # t2: r2 = x[12] - x[13]
   sub   $t3, $t7, $t6                       # t3: r3 = x[15] - x[14]
   mfhi  $s4
   add   $t8, $t9                            # x[28] += x[29]
   sll   $s3, 1                              # (MULT32(r2, cPI3_8) +
                                             #     MULT32(r3, cPI1_8)) << 1
   sw    $s3, 9*4($a1)
   add   $v0, $v1                            # x[30] += x[31]
   add   $t9, $t5, $t4                       # x[29]  = x[ 13] + x[ 12]
   add   $v1, $t7, $t6                       # x[31]  = x[ 15] + x[ 14]
   sll   $s4, 1                              # (MULT32(r3, cPI3_8) -
                                             #     MULT32(r2, cPI1_8)) << 1
   sw    $s4, 11*4($a1)
   sw    $t8, 28*4($a1)                      # t8: x[28]
   sw    $t9, 29*4($a1)                      # t9: x[29]
   sw    $v0, 30*4($a1)                      # v0: x[30]
   sw    $v1, 31*4($a1)                      # v1: x[31]
   sw    $t0, 12*4($a1)                      # x[12] = r0
   sw    $t3, 13*4($a1)                      # x[13] = r3
   sw    $t1, 14*4($a1)                      # x[14] = r1
   sw    $t2, 15*4($a1)                      # x[15] = r2

   #### 16 point butterfly (in place, 4 register) ####
   #### STIN void mdct_butterfly_16(DATA_TYPE *x) ####
   lw    $t4, 0($a1)                         # t4: x[ 0]
   lw    $t5, 4($a1)                         # t5: x[ 1]
   lw    $t6, 2*4($a1)                       # t6: x[ 2]
   lw    $t7, 3*4($a1)                       # t7: x[ 3]
   lw    $t8, 8*4($a1)                       # t8: x[ 8]
   lw    $t9, 9*4($a1)                       # t9: x[ 9]
   lw    $v0, 10*4($a1)                      # v0: x[ 10]
   lw    $v1, 11*4($a1)                      # v1: x[ 11]
   sub   $t0, $t8, $t9                       # t0: r0 = x[ 8] - x[ 9]
   sub   $t1, $v0, $v1                       # t1: r1 = x[ 10] - x[ 11]
   sub   $t2, $t5, $t4                       # t2: r2 = x[ 1] - x[ 0]
   sub   $t3, $t7, $t6                       # t3: r3 = x[ 3] - x[ 2]
   sub   $s3, $t0, $t1                       # s3: r0 - r1
   add   $s4, $t2, $t3                       # s4: r2 + r3
   add   $t0, $t1                            # t0: r0 + r1
   sub   $t3, $t2                            # t3: r3 - r2
   mult  $s3, $s2                            # MULT32((r0-r1), cPI2_8)
   add   $t8, $t9                            # x[ 8] += x[ 9]
   add   $v0, $v1                            # x[10] += x[11]
   add   $t9, $t5, $t4                       # x[ 9]  = x[ 1] + x[0]
   add   $v1, $t7, $t6                       # x[11]  = x[ 3] + x[2]
   mfhi  $s3
   mult  $s4, $s2                            # MULT32((r3+r2), cPI2_8)
   sw    $t8, 8*4($a1)
   sw    $v0, 10*4($a1)
   sw    $t9, 9*4($a1)
   sw    $v1, 11*4($a1)
   mfhi  $s4
   mult  $t0, $s2                            # MULT32((r0+r1), cPI2_8)
   sll   $s3, 1                              # MULT31((r0-r1), cPI2_8)
   sw    $s3, 0($a1)                         # x[0] = MULT32((r0-r1), cPI2_8)
   lw    $t4, 4*4($a1)                       # t4: x[ 4]
   lw    $t5, 5*4($a1)                       # t5: x[ 5]
   mfhi  $t0
   mult  $t3, $s2                            # MULT32((r3-r2), cPI2_8)
   sll   $s4, 1                              # MULT31((r3+r2), cPI2_8)
   sw    $s4, 4($a1)                         # x[1] = MULT31((r3+r2), cPI2_8)
   lw    $t6, 6*4($a1)                       # t6: x[ 6]
   lw    $t7, 7*4($a1)                       # t7: x[ 7]
   mfhi  $t3
   sll   $t0, 1                              # MULT31((r0+r1), cPI2_8)
   sw    $t0, 2*4($a1)                       # x[2] = MULT31((r0+r1), cPI2_8)
   lw    $t8, 12*4($a1)                      # t8: x[ 12]
   lw    $t9, 13*4($a1)                      # t9: x[ 13]
   lw    $v0, 14*4($a1)                      # v0: x[ 14]
   lw    $v1, 15*4($a1)                      # v1: x[ 15]
   sll   $t3, 1                              # MULT31((r3-r2), cPI2_8)
   sw    $t3, 3*4($a1)                       # x[3] = MULT31((r3-r2), cPI2_8)
   sub   $t2, $t8, $t9                       # t2: r0 = x[12] - x[13]
   sub   $t3, $v0, $v1                       # t3: r1 = x[14] - x[15]
   sub   $t0, $t4, $t5                       # t0: r2 = x[ 4] - x[ 5]
   sub   $t1, $t7, $t6                       # t1: r3 = x[ 7] - x[ 6]
   add   $t8, $t9                            # x[12] += x[13]
   add   $v0, $v1                            # x[14] += x[15]
   add   $t9, $t5, $t4                       # x[13]  = x[ 5] + x[4]
   add   $v1, $t7, $t6                       # x[15]  = x[ 7] + x[6]
   sw    $t8, 12*4($a1)
   sw    $v0, 14*4($a1)
   sw    $t9, 13*4($a1)
   sw    $v1, 15*4($a1)
   sw    $t2, 4*4($a1)                       # x[ 4] = r2
   sw    $t1, 5*4($a1)                       # x[ 5] = r1
   sw    $t3, 6*4($a1)                       # x[ 6] = r3
   sw    $t0, 7*4($a1)                       # x[ 7] = r0

   #### mdct_butterfly_8(x) ####
   lw    $t4, 0($a1)                         # t4: x[0]
   lw    $t5, 4($a1)                         # t5: x[1]
   lw    $t6, 2*4($a1)                       # t6: x[2]
   lw    $t7, 3*4($a1)                       # t7: x[3]
   lw    $t8, 4*4($a1)                       # t8: x[4]
   lw    $t9, 5*4($a1)                       # t9: x[5]
   lw    $t0, 6*4($a1)                       # t0: x[6]
   lw    $t1, 7*4($a1)                       # t1: x[7]
   add   $t2, $t4, $t5                       # t2: r0 = x[0] + x[1]
   sub   $t4, $t5                            # t4: r1 = x[0] - x[1]
   add   $t3, $t6, $t7                       # t3: r2 = x[2] + x[3]
   sub   $t6, $t7                            # t6: r3 = x[2] - x[3]
   add   $t5, $t8, $t9                       # t5: r4 = x[4] + x[5]
   sub   $t8, $t9                            # t8: r5 = x[4] - x[5]
   add   $t7, $t0, $t1                       # t7: r6 = x[6] + x[7]
   sub   $t0, $t1                            # t0: r7 = x[6] - x[7]
   add   $t1, $t8, $t6                       # x[0] = r5   + r3
   sub   $v0, $t0, $t4                       # x[1] = r7   - r1
   sub   $t8, $t6                            # x[2] = r5   - r3
   add   $t0, $t4                            # x[3] = r7   + r1
   sub   $t6, $t5, $t2                       # x[4] = r4   - r0
   sub   $t4, $t7, $t3                       # x[5] = r6   - r2
   add   $t5, $t2                            # x[6] = r4   + r0
   add   $t7, $t3                            # x[7] = r6   + r2
   sw    $t1, 0($a1)
   sw    $v0, 4($a1)
   sw    $t8, 2*4($a1)
   sw    $t0, 3*4($a1)
   sw    $t6, 4*4($a1)
   sw    $t4, 5*4($a1)
   sw    $t5, 6*4($a1)
   sw    $t7, 7*4($a1)

   #### mdct_butterfly_8(x + 8) ####
   lw    $t4, 8*4($a1)
   lw    $t5, 9*4($a1)
   lw    $t6, 10*4($a1)
   lw    $t7, 11*4($a1)
   lw    $t8, 12*4($a1)
   lw    $t9, 13*4($a1)
   lw    $t0, 14*4($a1)
   lw    $t1, 15*4($a1)
   add   $t2, $t4, $t5                       # t2: r0 = x[8] + x[9]
   sub   $t4, $t5                            # t4: r1 = x[8] - x[9]
   add   $t3, $t6, $t7                       # t3: r2 = x[10] + x[11]
   sub   $t6, $t7                            # t6: r3 = x[10] - x[11]
   add   $t5, $t8, $t9                       # t5: r4 = x[12] + x[13]
   sub   $t8, $t9                            # t8: r5 = x[12] - x[13]
   add   $t7, $t0, $t1                       # t7: r6 = x[14] + x[15]
   sub   $t0, $t1                            # t0: r7 = x[14] - x[15]
   add   $t1, $t8, $t6                       # x[8] = r5   + r3
   sub   $v0, $t0, $t4                       # x[9] = r7   - r1
   sub   $t8, $t6                            # x[10] = r5   - r3
   add   $t0, $t4                            # x[11] = r7   + r1
   sub   $t6, $t5, $t2                       # x[12] = r4   - r0
   sub   $t4, $t7, $t3                       # x[13] = r6   - r2
   add   $t5, $t2                            # x[14] = r4   + r0
   add   $t7, $t3                            # x[15] = r6   + r2
   sw    $t1, 8*4($a1)
   sw    $v0, 9*4($a1)
   sw    $t8, 10*4($a1)
   sw    $t0, 11*4($a1)
   sw    $t6, 12*4($a1)
   sw    $t4, 13*4($a1)
   sw    $t5, 14*4($a1)
   sw    $t7, 15*4($a1)


   #### 16 point butterfly (in place, 4 register) ####
   #### mdct_butterfly_16(x + 16) ####
   lw    $t4, 0+16*4($a1)                    # t4: x[ 0]
   lw    $t5, 4+16*4($a1)                    # t5: x[ 1]
   lw    $t6, 2*4+16*4($a1)                  # t6: x[ 2]
   lw    $t7, 3*4+16*4($a1)                  # t7: x[ 3]
   lw    $t8, 8*4+16*4($a1)                  # t8: x[ 8]
   lw    $t9, 9*4+16*4($a1)                  # t9: x[ 9]
   lw    $v0, 10*4+16*4($a1)                 # v0: x[ 10]
   lw    $v1, 11*4+16*4($a1)                 # v1: x[ 11]
   sub   $t0, $t8, $t9                       # t0: r0 = x[ 8] - x[ 9]
   sub   $t1, $v0, $v1                       # t1: r1 = x[ 10] - x[ 11]
   sub   $t2, $t5, $t4                       # t2: r2 = x[ 1] - x[ 0]
   sub   $t3, $t7, $t6                       # t3: r3 = x[ 3] - x[ 2]
   sub   $s3, $t0, $t1                       # s3: r0 - r1
   add   $s4, $t2, $t3                       # s4: r2 + r3
   add   $t0, $t1                            # t0: r0 + r1
   sub   $t3, $t2                            # t3: r3 - r2
   mult  $s3, $s2                            # MULT32((r0-r1), cPI2_8)
   add   $t8, $t9                            # x[ 8] += x[ 9]
   add   $v0, $v1                            # x[10] += x[11]
   add   $t9, $t5, $t4                       # x[ 9]  = x[ 1] + x[0]
   add   $v1, $t7, $t6                       # x[11]  = x[ 3] + x[2]
   mfhi  $s3
   mult  $s4, $s2                            # MULT32((r3+r2), cPI2_8)
   sw    $t8, 8*4+16*4($a1)
   sw    $v0, 10*4+16*4($a1)
   sw    $t9, 9*4+16*4($a1)
   sw    $v1, 11*4+16*4($a1)
   mfhi  $s4
   mult  $t0, $s2                            # MULT32((r0+r1), cPI2_8)
   sll   $s3, 1                              # MULT31((r0-r1), cPI2_8)
   sw    $s3, 0+16*4($a1)                    # x[0] = MULT32((r0-r1), cPI2_8)
   lw    $t4, 4*4+16*4($a1)                  # t4: x[ 4]
   lw    $t5, 5*4+16*4($a1)                  # t5: x[ 5]
   mfhi  $t0
   mult  $t3, $s2                            # MULT32((r3-r2), cPI2_8)
   sll   $s4, 1                              # MULT31((r3+r2), cPI2_8)
   sw    $s4, 4+16*4($a1)                    # x[1] = MULT31((r3+r2), cPI2_8)
   lw    $t6, 6*4+16*4($a1)                  # t6: x[ 6]
   lw    $t7, 7*4+16*4($a1)                  # t7: x[ 7]
   mfhi  $t3
   sll   $t0, 1                              # MULT31((r0+r1), cPI2_8)
   sw    $t0, 2*4+16*4($a1)                  # x[2] = MULT31((r0+r1), cPI2_8)
   lw    $t8, 12*4+16*4($a1)                 # t8: x[ 12]
   lw    $t9, 13*4+16*4($a1)                 # t9: x[ 13]
   lw    $v0, 14*4+16*4($a1)                 # v0: x[ 14]
   lw    $v1, 15*4+16*4($a1)                 # v1: x[ 15]
   sll   $t3, 1                              # MULT31((r3-r2), cPI2_8)
   sw    $t3, 3*4+16*4($a1)                  # x[3] = MULT31((r3-r2), cPI2_8)
   sub   $t2, $t8, $t9                       # t2: r2 = x[12] - x[13]
   sub   $t3, $v0, $v1                       # t3: r3 = x[14] - x[15]
   sub   $t0, $t4, $t5                       # t0: r0 = x[ 4] - x[ 5]
   sub   $t1, $t7, $t6                       # t1: r1 = x[ 7] - x[ 6]
   add   $t8, $t9                            # x[12] += x[13]
   add   $v0, $v1                            # x[14] += x[15]
   add   $t9, $t5, $t4                       # x[13]  = x[ 5] + x[4]
   add   $v1, $t7, $t6                       # x[15]  = x[ 7] + x[6]
   sw    $t8, 12*4+16*4($a1)
   sw    $v0, 14*4+16*4($a1)
   sw    $t9, 13*4+16*4($a1)
   sw    $v1, 15*4+16*4($a1)
   sw    $t2, 4*4+16*4($a1)                  # x[ 4] = r2
   sw    $t1, 5*4+16*4($a1)                  # x[ 5] = r1
   sw    $t3, 6*4+16*4($a1)                  # x[ 6] = r3
   sw    $t0, 7*4+16*4($a1)                  # x[ 7] = r0

   #### mdct_butterfly_8(x) ####
   lw    $t4, 0+16*4($a1)                    # t4: x[0]
   lw    $t5, 4+16*4($a1)                    # t5: x[1]
   lw    $t6, 2*4+16*4($a1)                  # t6: x[2]
   lw    $t7, 3*4+16*4($a1)                  # t7: x[3]
   lw    $t8, 4*4+16*4($a1)                  # t8: x[4]
   lw    $t9, 5*4+16*4($a1)                  # t9: x[5]
   lw    $t0, 6*4+16*4($a1)                  # t0: x[6]
   lw    $t1, 7*4+16*4($a1)                  # t1: x[7]
   add   $t2, $t4, $t5                       # t2: r0 = x[0] + x[1]
   sub   $t4, $t5                            # t4: r1 = x[0] - x[1]
   add   $t3, $t6, $t7                       # t3: r2 = x[2] + x[3]
   sub   $t6, $t7                            # t6: r3 = x[2] - x[3]
   add   $t5, $t8, $t9                       # t5: r4 = x[4] + x[5]
   sub   $t8, $t9                            # t8: r5 = x[4] - x[5]
   add   $t7, $t0, $t1                       # t7: r6 = x[6] + x[7]
   sub   $t0, $t1                            # t0: r7 = x[6] - x[7]
   add   $t1, $t8, $t6                       # x[0] = r5   + r3
   sub   $v0, $t0, $t4                       # x[1] = r7   - r1
   sub   $t8, $t6                            # x[2] = r5   - r3
   add   $t0, $t4                            # x[3] = r7   + r1
   sub   $t6, $t5, $t2                       # x[4] = r4   - r0
   sub   $t4, $t7, $t3                       # x[5] = r6   - r2
   add   $t5, $t2                            # x[6] = r4   + r0
   add   $t7, $t3                            # x[7] = r6   + r2
   sw    $t1, 0+16*4($a1)
   sw    $v0, 4+16*4($a1)
   sw    $t8, 2*4+16*4($a1)
   sw    $t0, 3*4+16*4($a1)
   sw    $t6, 4*4+16*4($a1)
   sw    $t4, 5*4+16*4($a1)
   sw    $t5, 6*4+16*4($a1)
   sw    $t7, 7*4+16*4($a1)

   #### mdct_butterfly_8(x + 8) ####
   lw    $t4, 8*4+16*4($a1)
   lw    $t5, 9*4+16*4($a1)
   lw    $t6, 10*4+16*4($a1)
   lw    $t7, 11*4+16*4($a1)
   lw    $t8, 12*4+16*4($a1)
   lw    $t9, 13*4+16*4($a1)
   lw    $t0, 14*4+16*4($a1)
   lw    $t1, 15*4+16*4($a1)
   add   $t2, $t4, $t5                       # t2: r0 = x[8] + x[9]
   sub   $t4, $t5                            # t4: r1 = x[8] - x[9]
   add   $t3, $t6, $t7                       # t3: r2 = x[10] + x[11]
   sub   $t6, $t7                            # t6: r3 = x[10] - x[11]
   add   $t5, $t8, $t9                       # t5: r4 = x[12] + x[13]
   sub   $t8, $t9                            # t8: r5 = x[12] - x[13]
   add   $t7, $t0, $t1                       # t7: r6 = x[14] + x[15]
   sub   $t0, $t1                            # t0: r7 = x[14] - x[15]
   add   $t1, $t8, $t6                       # x[8] = r5   + r3
   sub   $v0, $t0, $t4                       # x[9] = r7   - r1
   sub   $t8, $t6                            # x[10] = r5   - r3
   add   $t0, $t4                            # x[11] = r7   + r1
   sub   $t6, $t5, $t2                       # x[12] = r4   - r0
   sub   $t4, $t7, $t3                       # x[13] = r6   - r2
   add   $t5, $t2                            # x[14] = r4   + r0
   add   $t7, $t3                            # x[15] = r6   + r2
   sw    $t1, 8*4+16*4($a1)
   sw    $v0, 9*4+16*4($a1)
   sw    $t8, 10*4+16*4($a1)
   sw    $t0, 11*4+16*4($a1)
   sw    $t6, 12*4+16*4($a1)
   sw    $t4, 13*4+16*4($a1)
   sw    $t5, 14*4+16*4($a1)
   sw    $t7, 15*4+16*4($a1)
   addiu $a0, -32
   .set  noreorder
   .set  nomacro
   bgtz  $a0, mdct_butterfly_32_lp           # for(j=0;j<points;j+=32)
    addiu $a1, 32 * 4

mdct_butterfly_32_end:
   lw    $a1, 60($sp)
   lw    $a0, 56($sp)
   lw    $a2, 0($sp)                         # shift
   li    $t0, 0                              # int  bit   = 0;
   sll   $a0, 1                              # a0: (n >> 1) * 4
   addu  $t2, $a1, $a0                       # DATA_TYPE *w = x+(n>>1);

mdct_bitreverse_lp:
   bitrev   $t1, $t0                         # bitrev12(bit);
   srav  $t1, $t1, $a2                       # (b>>shift)
   addiu $t2, -8                             # w    -= 2;
   sll   $t1, 2                              # (b>>shift)*4
   add   $t3, $a1, $t1                       # DATA_TYPE *xx = x + (b>>shift);
   slt   $t1, $t3, $t2                       # if(w>xx){
   beqz  $t1, mdct_bitreverse_lp_end
    addiu $t0, 16                            # bit++ << 4
   .set  macro
   .set  reorder
   lw    $t1, 0($t3)                         # r1    = xx[0];
   lw    $t4, 0($t2)                         # w[0]
   lw    $t5, 4($t3)                         # r2    = xx[1];
   lw    $t6, 4($t2)                         # w[1]
   sw    $t4, 0($t3)                         # xx[0] = w[0];
   sw    $t1, 0($t2)                         # w[0]  = r1;
   sw    $t6, 4($t3)                         # xx[1] = w[1];
   sw    $t5, 4($t2)                         # w[1]  = r2;
mdct_bitreverse_lp_end:
   slt   $t1, $a1, $t2
   bnez  $t1, mdct_bitreverse_lp

   #******************************** mdct_step7 ********************
   lw    $a2, 4($sp)                         # step
   la    $s0, sincos_lookup0
   la    $t5, sincos_lookup1
   sll   $t1, $a2, 1                         # t1: (step >> 1) * 4
   addu  $s0, $t1                            # s0: *T = sincos_lookup0+(step>>1)
   slti  $t2, $a2, 4
   movn  $s0, $t5, $t2                       # LOOKUP_T  *T = (step>=4)?
                                             # (sincos_lookup0+(step>>1)):
                                             # sincos_lookup1;
   move  $s1, $a1                            # DATA_TYPE *w0   = x;
   addu  $s2, $a1, $a0                       # DATA_TYPE *w1   = x+(n>>1);
   addiu $s3, $s0, 4*1024                    # LOOKUP_T  *Ttop = T+1024;
   sll   $a2, 2                              # step * 4

   # pipeline warm-up before loop
   lw    $t1, 4($s1)                         # t1: w0[1]
   lw    $t0, 0($s1)                         # t0: w0[0]
mdct_step7_lp1:
   lw    $t2, -8($s2)                        # t2: w1[0]
   lw    $t3, -4($s2)                        # t3: w1[1]
   lw    $v0, 0($s0)                         # v0: T[0]
   lw    $v1, 4($s0)                         # v1: T[1]
   addu  $t5, $t0, $t2                       # t5: r0 = w0[0]  + w1[0];
   sub   $t9, $t3, $t1                       # t9: r1 = w1[1]  - w0[1];
   mult  $t5, $v1                            # MULT32(r0, T[1])
   mtlo  $zero
   madd  $t9, $v0                            # MULT32(r0, T[1]) +
                                             #     MULT32(r1, T[0]);
   add   $s0, $a2                            # T+=step;
   add   $t1, $t3                            # w0[1] + w1[1]
   sub   $t0, $t2                            # w0[0] - w1[0]
   sra   $t1, 1                              # r0 = (w0[1] + w1[1])>>1;
   mfhi  $t4                                 # r2 = MULT32(r0, T[1]) +
                                             #     MULT32(r1, T[0]);
   mult  $t9, $v1                            # MULT32(r1, T[1])
   mtlo  $a3
   msub  $t5, $v0                            # MULT32(r1, T[1]) -
                                             #     MULT32(r0, T[0]);
   sra   $t6, $t0, 1                         # r1 = (w0[0] - w1[0])>>1;
   add   $t3, $t1, $t4                       # r0 + r2;
   sub   $t1, $t4                            # r0 - r2
   addiu $s2, -8;
   mfhi  $t5                                 # r3 = MULT32(r1, T[1]) -
                                             #        MULT32(r0, T[0]);
   sw    $t3, 0($s1)                         # w0[0]  = r0 + r2;
   sw    $t1, 0($s2)                         # w1[0]  = r0 - r2;
   slt   $t9, $s0, $s3                       # while(T<Ttop)
   addiu $s1, 8                              # w0    += 2;
   lw    $t1, 4($s1)                         # t1: w0[1]
   lw    $t0, 0($s1)                         # t0: w0[0]
   add   $t2, $t6, $t5                       # r1 + r3
   sub   $t6, $t5, $t6                       # r3 - r1
   sw    $t2, -4($s1)                        # w0[1]  = r1 + r3;
   .set  noreorder
   .set  nomacro
   bnez  $t9, mdct_step7_lp1
    sw   $t6, 4($s2)                         # w1[1]  = r3 - r1;

   # pipeline warm-up before loop
   sub   $s0, $a2                            # T-=step;
   lw    $t1, 4($s1)                         # t1: w0[1]
   lw    $t0, 0($s1)                         # t0: w0[0]
mdct_step7_lp2:
   lw    $t2, -8($s2)                        # t2: w1[0]
   lw    $t3, -4($s2)                        # t3: w1[1]
   lw    $v0, 0($s0)                         # v0: T[0]
   lw    $v1, 4($s0)                         # v1: T[1]
   add   $t5, $t0, $t2                       # t5: r0 = w0[0] + w1[0];
   sub   $t9, $t3, $t1                       # t9: r1 = w1[1] - w0[1];
   mult  $t5, $v0                            # MULT32(r0, T[0])
   mtlo  $zero
   madd  $t9, $v1                            # MULT32(r0, T[0]) +
                                             #     MULT32(r1, T[1]);
   addiu $s2, -8;
   add   $t1, $t3                            # w0[1] + w1[1]
   sub   $t0, $t2                            # w0[0] - w1[0]
   sra   $t1, 1                              # r0 = (w0[1] + w1[1])>>1;
   mfhi  $t4                                 # r2 = MULT32(r0, T[1]) +
                                             #        MULT32(r1, T[0]);
   mult  $t9, $v0                            # MULT32(r1, T[0])
   mtlo  $a3
   msub  $t5, $v1                            # MULT32(r1, T[0]) -
                                             #     MULT32(r0, T[1]);
   sra   $t6, $t0, 1                         # r1 = (w0[0] - w1[0])>>1;
   add   $t3, $t1, $t4                       # r0 + r2;
   sub   $t1, $t4                            # r0 - r2
   sw    $t3, 0($s1)                         # w0[0]  = r0     + r2;
   mfhi  $t5                                 # r3 = MULT32(r1, T[0]) -
                                             #        MULT32(r0, T[1]);
   sw    $t1, 0($s2)                         # w1[0]  = r0 - r2;
   addiu $s1, 8                              # w0    += 2;
   sub   $s0, $a2                            # T-=step;
   slt   $t9, $s1, $s2                       # while(w0<w1);
   lw    $t1, 4($s1)                         # t1: w0[1]
   lw    $t0, 0($s1)                         # t0: w0[0]
   add   $t2, $t6, $t5                       # r1 + r3
   sub   $t6, $t5, $t6                       # r3 - r1
   sw    $t2, -4($s1)                        # w0[1]  = r1 + r3;
   bnez  $t9, mdct_step7_lp2
    sw   $t6, 4($s2)                         # w1[1]  = r3 - r1;

   .set  macro
   .set  reorder
#******************************** mdct_step8 ********************
   lw    $a2, 4($sp)                         # step (always >=0)
   la    $s0, sincos_lookup0                 # s0: T = sincos_lookup0;
   sra   $a2, 2                              # step>>=2;
   addu  $s2, $a1, $a0                       # DATA_TYPE *iX = x+(n>>1);
   addiu $t1, $a2, -1                        # step - 1
   bgtz  $t1, mdct_step8_default             # switch(step) {
   la    $s1, sincos_lookup1                 # s1: V = sincos_lookup1;
   beqz  $t1, mdct_step8_case1
   #### linear interpolation between table values: offset=0.25, step=0.5 ####
   lw    $t0, 0($s0)                         # t0 = *T
   lw    $t1, 4($s0)                         # t1 = *(T+1)
   addiu $s0, 8                              # T+=2

   # pipeline warm-up before loop
   lw    $v0, 0($s1)                         # v0 = *V
   lw    $v1, 4($s1)                         # v1 = *(V+1)
   lw    $t4, 0($a1)                         # r0 = x[0]
   lw    $t5, 4($a1)                         # r1 = x[1]
   sub   $t2, $v0, $t0                       # q0 = (v0-t0)
   sub   $t3, $v1, $t1                       # q1 = (v1-t1)
   sra   $t2, 2                              # q0 = (v0-t0)>>2
   sra   $t3, 2                              # q1 = (v1-t1)>>2
   add   $t0, $t2                            # t0 +=  (q0 = (v0-t0)>>2)
mdct_step8_case0_lp:
   add   $t1, $t3                            # t1 +=  (q1 = (v1-t1)>>2)
   negu  $t5, $t5                            # r1 = -x[1]
   # XPROD31( r0, r1, t0, t1, x, x+1 );
   mult  $t4, $t0                            # MULT32(r0,t0)
   mtlo  $zero
   madd  $t5, $t1                            # MULT32(r0,t0) + MULT32(r1,t1)
   lw    $t7, 3*4($a1)                       # r1  = x[3]
   lw    $t6, 2*4($a1)                       # r0  = x[2]
   sub   $t8, $v0, $t2                       # t8: new t0 = v0 - q0
   sub   $s5, $v1, $t3                       # s5: new t1 = v1 - q1
   mfhi  $s3
   mult  $t5, $t0                            # MULT32(r1,t0)
   mtlo  $a3
   msub  $t4, $t1                            # MULT32(r1,t0) - MULT32(r0,t1)
   negu  $t7, $t7                            # r1 = -x[3]
   sll   $s3, 1                              # MULT31(r0,t0) + MULT31(r1,t1)
   sw    $s3, 0($a1)
   mfhi  $s3
   # XPROD31( r0, r1, t0, t1, x+2, x+3 )
   mult  $t6, $t8                            # MULT32(r0,t0)
   mtlo  $zero
   madd  $t7, $s5                            # MULT32(r0,t0) + MULT32(r1,t1)
   lw    $t0, 0($s0)                         # t0 = *T
   lw    $t1, 4($s0)                         # t1 = *T+1
   sll   $s3, 1                              # MULT31(r1,t0) - MULT31(r0,t1)
   sw    $s3, 4($a1)
   mfhi  $s3
   mult  $t7, $t8                            # MULT32(r1,t0)
   mtlo  $a3
   msub  $t6, $s5                            # MULT32(r1,t0) + MULT32(r0,t1)
   lw    $t4, 4*4($a1)                       # r0 = x[4]
   lw    $t5, 5*4($a1)                       # r1 = x[5]
   sub   $t2, $t0, $v0                       # q0 = (t0-v0)
   sll   $s3, 1                              # MULT31(r0,t0) + MULT31(r1,t1)
   sw    $s3, 2*4($a1)
   mfhi  $s3
   sub   $t3, $t1, $v1                       # q1 = (t1-v1)
   sra   $t2, 2                              # q0 = (t0-v0)>>2
   sra   $t3, 2                              # q1 = (t1-v1)>>2
   add   $v0, $t2                            # v0 +=  (q0 = (t0-v0)>>2)
   add   $v1, $t3                            # v1 +=  (q1 = (t1-v1)>>2)
   negu  $t5, $t5                            # r1 = -x[1]
   sll   $s3, 1                              # MULT31(r1,t0) - MULT31(r0,t1)
   sw    $s3, 3*4($a1)
   # XPROD31( r0, r1, v0, v1, x+4, x+5 );
   mult  $t4, $v0                            # MULT32(r0,v0)
   mtlo  $zero
   madd  $t5, $v1                            # MULT32(r0,v0) + MULT32(r1,v1)
   lw    $t7, 7*4($a1)                       # r1  = x[7]
   lw    $t6, 6*4($a1)                       # r0  = x[6]
   sub   $t8, $t0, $t2                       # t8: new v0 = t0 - q0
   sub   $s5, $t1, $t3                       # s5: new v1 = t1 - q1
   mfhi  $s3
   mult  $t5, $v0                            # MULT32(r1,v0)
   mtlo  $a3
   msub  $t4, $v1                            # MULT32(r1,v0) + MULT32(r0,v1)
   negu  $t7, $t7                            # r1 = -x[7]
   lw    $v0, 2*4($s1)                       # v0 = *V
   lw    $v1, 3*4($s1)                       # v1 = *(V+1)
   sll   $s3, 1                              # MULT31(r0,t0) + MULT31(r1,t1)
   sw    $s3, 4*4($a1)
   mfhi  $s3
   # XPROD31( r0, r1, v0, v1, x+5, x+6 )
   mult  $t6, $t8                            # MULT32(r0,v0)
   mtlo  $zero
   madd  $t7, $s5                            # MULT32(r0,v0) + MULT32(r1,v1)
   addiu $a1, 8*4                            # x += 8
   addiu $s0, 2*4                            # T += 2
   slt   $t9, $a1, $s2                       # x<iX
   sll   $s3, 1                              # MULT31(r1,v0) - MULT31(r0,v1)
   sw    $s3, -2*4($a1)
   mfhi  $s3
   mult  $t7, $t8                            # MULT32(r1,v0)
   mtlo  $a3
   msub  $t6, $s5                            # MULT32(r1,v0) + MULT32(r0,v1)
   addiu $s1, 2*4                            # V += 2
   lw    $t4, 0($a1)                         # r0 = x[0]
   lw    $t5, 4($a1)                         # r1 = x[1]
   sll   $s3, 1                              # MULT31(r0,v0) + MULT31(r1,v1)
   mfhi  $s4
   sw    $s3, -4($a1)
   sub   $t2, $v0, $t0                       # q0 = (v0-t0)
   sub   $t3, $v1, $t1                       # q1 = (v1-t1)
   sra   $t2, 2                              # q0 = (v0-t0)>>2
   sra   $t3, 2                              # q1 = (v1-t1)>>2
   add   $t0, $t2                            # t0 +=  (q0 = (v0-t0)>>2)
   sll   $s4, 1                              # MULT31(r1,v0) - MULT31(r0,v1)
   .set  noreorder
   .set  nomacro
   bnez  $t9, mdct_step8_case0_lp            # while(x<iX)
    sw   $s4, -2*4($a1)

   b mdct_step8_end
    lw   $s0, 16($sp)
   .set  macro
   .set  reorder

mdct_step8_case1:
   #### linear interpolation between table values: offset=0.5, step=1 ####
   lw    $t2, 0($s0)                         # t2: t0 = *T
   lw    $s5, 4($s0)                         # s5: t1 = *(T+1)
   addiu $s0, 8                              # T+=2
   sra   $t2, 1
   sra   $s5, 1

   # pipeline warm-up before loop
   lw    $t1, 4($a1)                         # t1: x[1]
   lw    $t0, 0($a1)                         # t0: r0 = x[0]
   lw    $v0, 0($s1)                         # v0
   lw    $v1, 4($s1)                         # v1
   sra   $v0, 1
   sra   $v1, 1
   negu  $t1, $t1                            # t1: r1 = -x[1]
   add   $t2, $v0                            # t2: t0 += (v0 = (*V++)>>1);
mdct_step8_case1_lp:
   add   $t3, $v1, $s5                       # t3: t1 += (v1 = (*V++)>>1);
   #XPROD31( r0, r1, T[0], T[1], x, x+1);
   mult  $t0, $t2                            # MULT32(r0,t0)
   mtlo  $zero
   madd  $t1, $t3                            # MULT32(r0,t0) + MULT32(r1,t1)
   addiu $s1, 8                              # V+=2
   lw    $t6, 12($a1)                        # t6: x[3]
   lw    $t7, 8($a1)                         # t7: r0 = x[2]
   lw    $t8, 0($s0)                         # t8: t0
   mfhi  $t4
   mult  $t1, $t2                            # MULT32(r1,T[0])
   mtlo  $a3
   msub  $t0, $t3                            # MULT32(r1,T[0]) - MULT32(r0,T[1])
   lw    $s5, 4($s0)                         # s5: t1
   sra   $t8, 1
   sll   $t4, 1                              # MULT31(r0,T[0]) + MULT31(r1,T[1])
   sw    $t4, 0($a1)
   mfhi  $t5
   sra   $s5, 1
   negu  $t6, $t6                            # t6: r1 = -x[3]
   add   $v0, $t8                            # t8: v0 += (t0 = (*T++)>>1);
   add   $v1, $s5                            # s5: v1 += (t1 = (*T++)>>1);
   #XPROD31( r0, r1, v0, v1, x, x+1);
   mult  $t7, $v0                            # MULT32(r0,v0)
   mtlo  $zero
   madd  $t6, $v1                            # MULT32(r0,v0) + MULT32(r1,v1)
   sll   $t5, 1                              # MULT31(r1,T[0]) - MULT31(r0,T[1])
   sw    $t5, 4($a1)
   addiu $s0, 2*4                            # T+=2
   addiu $a1, 4*4                            # x+=4
   mfhi  $t4
   mult  $t6, $v0                            # MULT32(r1,v0)
   mtlo  $a3
   msub  $t7, $v1                            # MULT32(r1,v0) - MULT32(r0,v1)
   slt   $t9, $a1, $s2                       # x<iX
   lw    $t1, 4($a1)                         # t1: x[1]
   lw    $t0, 0($a1)                         # t0: r0 = x[0]
   sll   $t4, 1                              # MULT31(r0,v0) + MULT31(r1,v1)
   sw    $t4, -2*4($a1)
   mfhi  $t5
   lw    $v0, 0($s1)                         # v0
   lw    $v1, 4($s1)                         # v1
   sra   $v0, 1
   sra   $v1, 1
   negu  $t1, $t1                            # t1: r1 = -x[1]
   add   $t2, $v0, $t8                       # t2: t0 += (v0 = (*V++)>>1);
   sll   $t5, 1                              # MULT31(r1,T[0]) - MULT31(r0,T[1])
   .set  noreorder
   .set  nomacro
   bnez  $t9, mdct_step8_case1_lp            # while(x<iX)
    sw   $t5, -4($a1)

   b mdct_step8_end
    lw   $s0, 16($sp)
   .set  macro
   .set  reorder

mdct_step8_default:                          # most common case
   la    $t5, sincos_lookup1
   sll   $t1, $a2, 1                         # t1: (step >> 1) * 4
   slti  $t2, $a2, 4
   addu  $s0, $t1                            # s0: *T = sincos_lookup0+(step>>1)
   movn  $s0, $t5, $t2                       # LOOKUP_T    *T = (step>=4)?
                                             # (sincos_lookup0+(step>>1)):
                                             # sincos_lookup1;
   sll   $a2, 2                              # step *4

   lw    $t1, 4($a1)                         # t1: x[1]
   lw    $t0, 0($a1)                         # t0: r0 = x[0]
   lw    $t2, 0($s0)                         # t2: T[0]
   negu  $t1, $t1                            # t1: r1 = -x[1]
   lw    $t3, 4($s0)                         # t3: T[1]
   #XPROD31( r0, r1, T[0], T[1], x, x+1);
   mult  $t0, $t2                            # MULT32(r0,T[0])
mdct_step8_default_lp:
   mtlo  $zero
   madd  $t1, $t3                            # MULT32(r0,T[0]) + MULT32(r1,T[1])
   addu  $s0, $a2                            # T+=step
   addiu $a1, 2*4                            # x+=2
   mfhi  $t4
   mult  $t1, $t2                            # MULT32(r1,T[0])
   mtlo  $a3
   msub  $t0, $t3                            # MULT32(r1,T[0]) - MULT32(r0,T[1])
   lw    $t1, 4($a1)                         # t1: x[1]
   lw    $t0, 0($a1)                         # t0: r0 = x[0]
   sll   $t4, 1                              # MULT31(r0,T[0]) + MULT31(r1,T[1])
   sw    $t4, -2*4($a1)
   mfhi  $t5
   lw    $t2, 0($s0)                         # t2: T[0]
   negu  $t1, $t1                            # t1: r1 = -x[1]
   lw    $t3, 4($s0)                         # t3: T[1]
   #XPROD31( r0, r1, T[0], T[1], x, x+1);
   mult  $t0, $t2                            # MULT32(r0,T[0])
   slt   $t9, $a1, $s2                       # x<iX
   sll   $t5, 1                              # MULT31(r1,T[0]) - MULT31(r0,T[1])
   .set  noreorder
   .set  nomacro
   bnez  $t9, mdct_step8_default_lp          # while(x<iX)
    sw   $t5, -4($a1)
   .set  macro
   .set  reorder

   lw    $s0, 16($sp)
mdct_step8_end:
   lw    $s1, 20($sp)
   lw    $s2, 24($sp)
   lw    $s3, 28($sp)
   lw    $s4, 32($sp)
   lw    $s5, 36($sp)
   lw    $s6, 40($sp)
   lw    $s7, 44($sp)
   lw    $s8, 48($sp)
   lw    $ra, 52($sp)
   addiu $sp, 56
   jr    $ra
   .end  mdct_backward
#****************************************************************************

#/***************************************************************************
#*
#*  Function: mdct_unroll_lap
#*
#*  Description:
#*
#*  Parameters:
#*
#*      a0      :  n0
#*      a1      :  n1
#*      a2      :  lw
#*      a3      :  w
#*      t0      :  in
#*      t1      :  right
#*      t2      :  w0
#*      t3      :  w1
#*      t4      :  out
#*      t5      :  step
#*      t6      :  start
#*      t7      :  end
#*      s0      :  l
#*      s1      :  r
#*      s2      :  wR
#*      s3      :  wL
#*      s4      :  preLap
#*      s5      :  halfLap
#*      s6      :  postLap
#*
#*
#*  Reference: see mdct.c
#*
#*
#*  Notes:
#*
#***************************************************************************/

   .text
   .align   2
   .globl  mdct_unroll_lap
   .set  nomips16
   .set  nomicromips
   .ent  mdct_unroll_lap
   .type mdct_unroll_lap, @function

   #### void mdct_unroll_lap(int n0,int n1,
            #  int lW,int W,
            #  DATA_TYPE *in,
            #  DATA_TYPE *right,
            #  LOOKUP_T *w0,
            #  LOOKUP_T *w1,
            #  ogg_int16_t *out,
            #  int step,
            #  int start, /* samples, this frame */
            #  int end    /* samples, this frame */) ####

mdct_unroll_lap:
   .frame $sp, 32, $ra
   .set  noreorder
   .cpload $t9
   .set  reorder
   addiu $sp, -32
   sll   $t8, $a0, 1                         # (n0>>1) * 4
   sra   $v0, $a0, 2                         # n0>>2
   sw    $s0, 0($sp)
   sw    $s1, 4($sp)
   sw    $s2, 8($sp)
   sw    $s3, 12($sp)
   sw    $s4, 16($sp)
   sw    $s5, 20($sp)
   sw    $s6, 24($sp)
   lw    $t0, 48($sp)                        # *in
   lw    $t1, 52($sp)                        # *right
   lw    $t2, 56($sp)                        # *w0
   lw    $t3, 60($sp)                        # *w1
   lw    $t4, 64($sp)                        # *out
   lw    $t5, 68($sp)                        # step
   lw    $t6, 72($sp)                        # start
   lw    $t7, 76($sp)                        # end
   sll   $t9, $a1, 1                         # (n1>>1) * 4
   sra   $v1, $a1, 2                         # n1>>2
   sll   $t5, $t5, 1
   .set  noreorder
   .set  nomacro

   beqz  $a3, mdct_unroll_lap_W_zero         # if W == 0
    sw   $s7, 28($sp)
   #W=1
   beqz  $a2, mdct_unroll_lap_lW_zero        # if lW == 0
    li   $s4, 0                              # preLap=0
   .set  macro
   .set  reorder
   #W=1,lW=1
   move  $s5, $v1                            # halfLap=n1>>2
   sll   $v1, $v1, 2
   add   $s0, $t0, $t9                       # *l=in+n1>>1;
   add   $s1, $t1, $v1                       # *r=right+n1>>2;
   add   $s2, $t3, $t9                       # *wR=w1+(n1>>1);
   move  $s3, $t3                            # *wL=w1
   .set  noreorder
   .set  nomacro
   b mdct_unroll_lap_lW_W_end
    li   $s6, 0                              # postLap=0
   .set  macro
   .set  reorder

mdct_unroll_lap_lW_zero:
   #W=1,lW=0
   move  $s5, $v0                            # halfLap= n0>>2
   sub   $s6, $v1, $v0                       # postLap= n1>>2 - n0>>2
   sll   $v0, $v0, 2
   add   $s0, $t0, $t8                       # *l= in+n0>>1;
   add   $s1, $t1, $v0                       # *r= right+n0>>2;
   add   $s2, $t2, $t8                       # *wR= w0+(n0>>1);
   .set  noreorder
   .set  nomacro
   b mdct_unroll_lap_lW_W_end
    move $s3, $t2                            # *wL= w0

mdct_unroll_lap_W_zero:
   #W=0
   add   $s0, $t0, $t8                       # *l=in+ n0>>1;
   add   $s2, $t2, $t8                       # *wR= w0+(n0>>1);
   move  $s3, $t2                            # *wL=w0
   move  $s5, $v0                            # halfLap = n0 >>2
   beqz  $a2, mdct_unroll_lap_lW_zero1       # if lW=0
    li   $s6, 0                              # postLap = 0
   .set  macro
   .set  reorder
   #W=0, lW=1
   sub   $s4, $v1, $v0                       # preLap= n1>>2 - n0>>2
   move  $s5, $v0                            # halfLap= n0>>2
   sll   $v0, $v0, 2
   sll   $v1, $v1, 2
   .set  noreorder
   .set  nomacro
   b mdct_unroll_lap_lW_W_end
    add  $s1, $t1, $v1                       # *r=right+ n1>>2;
   .set  macro
   .set  reorder

mdct_unroll_lap_lW_zero1:
   #W=0, lW=0
   sll   $v0, $v0, 2
   add   $s1, $t1, $v0                       # *r=right+ n0>>2;
   li    $s4, 0                              # preLap=0

mdct_unroll_lap_lW_W_end:
   .set  noreorder
   .set  nomacro
# preLap preceeding direct-copy lapping from previous frame, if any
   beqz  $s4,  mdct_unroll_lap_croos_lap     # if(preLap)
    move $t1, $t6                            # t1: off = start
   .set  macro
   .set  reorder
   slt   $a1, $t6, $s4                       # off= (start<preLap?start:preLap);
   movz  $t1, $s4, $a1                       # t1: off
   move  $t0, $t7                            # t0: n= end
   slt   $s7, $t7, $s4                       # n= (end<preLap?end:preLap);
   movz  $t0, $s4, $s7                       # t0: end
   sll   $a1, $t1, 2                         # a1: off*4
   sub   $t7, $t7, $t0                       # end-= n;
   sub   $t6, $t6, $t1                       # start-= off;
   sub   $t0, $t1                            # t0: n - off
   .set  noreorder
   .set  nomacro
   #while(r>post) <=> while(r-off>r-n) <=> while(off<n) <=> while((n-off)>0)
   beqz  $t0,  mdct_unroll_lap_croos_lap
    sub  $s1, $s1, $a1                       # s1: r-= off;
   lw    $a1, -4($s1)                        # a1: (*--r)
   addiu $t0, $t0, -1
   addi  $s1, $s1, -4
   beqz  $t0, mdct_unroll_lap_prelap_while_loop_end
    sra  $a2, $a1, 9                         # a2: (*--r)>>9
   .set  macro
   .set  reorder
mdct_unroll_lap_prelap_while_loop:
   shll_s.w $a2, $a2, 16
   lw    $a1, -4($s1)                        # a1: (*--r)
   addiu $t0, $t0, -1
   sra   $a2, $a2, 16                        # CLIP_TO_15((*--r)>>9)
   addi  $s1, $s1, -4
   sh    $a2, 0($t4)                         # *out = CLIP_TO_15((*--r)>>9)
   sra   $a2, $a1, 9                         # a2: (*--r)>>9
   .set  noreorder
   .set  nomacro
   bnez  $t0,  mdct_unroll_lap_prelap_while_loop
    add  $t4, $t4, $t5                       # out+=step
   .set  macro
   .set  reorder
mdct_unroll_lap_prelap_while_loop_end:
   sra   $a2, $a1, 9
   shll_s.w $a2, $a2, 16
   sra   $a2, $a2, 16                        # CLIP_TO_15((*--r)>>9)
   sh    $a2, 0($t4)                         # *out = CLIP_TO_15((*--r)>>9)
   add   $t4, $t4, $t5                       # out+=step

# cross-lap; two halves due to wrap-around
mdct_unroll_lap_croos_lap:
   move  $t1, $t6                            # t1: off = start
   slt   $a1, $t6, $s5                       # start<halfLap?start:halfLap;
   movz  $t1, $s5, $a1                       # t1: off
   move  $t0, $t7                            # t0: n = end
   slt   $s7, $t7, $s5                       # end<halfLap?end:halfLap;
   movz  $t0, $s5, $s7                       # t0: n
   sub   $t6, $t6, $t1                       # start-= off;
   sll   $a3, $t1, 2
   sll   $a2, $t1, 3                         # a2= off*2
   sub   $s1, $s1, $a3                       # r-= off;
   sub   $s2, $s2, $a3                       # wR -= off;
   add   $s3, $s3, $a3                       # wL += off;
   sub   $t7, $t7, $t0                       # end-= n;
   sub   $t0, $t1                            # t0: n - off
   .set  noreorder
   .set  nomacro
   #while(r>post) <=> while(r-off>r-n) <=> while(off<n) <=> while((n-off)>0)
   beqz  $t0,  mdct_unroll_lap_croos_lap_1
    sub  $s0, $s0, $a2                       # l -= off*2;
   .set  macro
   .set  reorder
   addiu $s0, $s0, -8                        # l-=2
   lw    $a1, -4($s1)                        # *--r
   addi  $s1, $s1, -4
   lw    $a0, -4($s2)                        # *--wR
   addi  $s2, $s2, -4
   lw    $t8, 0($s0)                         # *l
   lw    $t9, 0($s3)                         # *wL
   addiu $t0, $t0, -1
   .set  noreorder
   .set  nomacro
   beqz  $t0,  mdct_unroll_lap_croos_while_loop_end
    addi  $s3, $s3, 4                        # wL++
   .set  macro
   .set  reorder
mdct_unroll_lap_croos_while_loop:
   mult  $a1, $a0                            # a1=MULT32(*--r,*--wR)
   mtlo  $zero
   addiu $s0, $s0, -8
   shilo $ac0, -1                            # a1=MULT31(*--r,*--wR)
   lw    $a1, -4($s1)
   addi  $s1, $s1, -4
   lw    $a0, -4($s2)
   dpaq_sa.l.w  $ac0, $t8, $t9               # MULT31(*--r,*--wR) + MULT31(*l,*wL++)
   mfhi  $s7                                 # s7=(MULT31(*--r,*--wR) +
                                             #        MULT31(*l,*wL++))
   addi  $s2, $s2, -4
   lw    $t8, 0($s0)
   lw    $t9, 0($s3)
   addi  $s3, $s3, 4
   sra   $s7, $s7, 9                         # s7=(MULT31(*--r,*--wR) +
                                             #        MULT31(*l,*wL++))>>9
   shll_s.w $s7, $s7, 16                     # *out = CLIP_TO_15((MULT31(*--r,*--wR)
                                             #         + MULT31(*l,*wL++))>>9);
   sra   $s7, $s7, 16
   sh    $s7, 0($t4)
   addiu $t0, $t0, -1
   .set  noreorder
   .set  nomacro
   bnez  $t0,  mdct_unroll_lap_croos_while_loop
    add  $t4, $t4, $t5                       # out+=step
   .set  macro
   .set  reorder
mdct_unroll_lap_croos_while_loop_end:
   mult  $a1, $a0                            # a1=MULT31(*--r,*--wR)
   mtlo  $zero
   shilo $ac0, -1
   dpaq_sa.l.w  $ac0, $t8, $t9               # MULT31(*--r,*--wR) +
                                             #     MULT31(*l,*wL++)
   mfhi  $s7
   sra   $s7, $s7, 9                         # s7=(MULT31(*--r,*--wR) +
                                             #     MULT31(*l,*wL++))>>9
   shll_s.w $s7, $s7, 16                     # *out = CLIP_TO_15((MULT31(*--r,*--wR)
                                             #         + MULT31(*l,*wL++))>>9);
   sra   $s7, $s7, 16
   sh    $s7, 0($t4)
   add   $t4, $t4, $t5                       # out+=step

# cross-lap1; two halves due to wrap-around
mdct_unroll_lap_croos_lap_1:
   move  $t1, $t6                            # t1: off= start
   slt   $a1, $t6, $s5                       # start<halfLap?start:halfLap
   movz  $t1, $s5, $a1                       # t1: off
   move  $t0, $t7                            # t0: n= end
   slt   $s7, $t7, $s5                       # end<halfLap?end:halfLap
   movz  $t0, $s5, $s7                       # t0: n
   sub   $t6, $t6, $t1                       # start-= off;
   sll   $a3, $t1, 2
   sll   $a2, $t1, 3                         # a2= off*2
   sub   $t7, $t7, $t0                       # end-= n;
   sub   $s2, $s2, $a3                       # wR -= off;
   sub   $t0, $t1                            # t0: n-off
   add   $s1, $s1, $a3                       # r+= off;
   add   $s3, $s3, $a3                       # wL += off;
   .set  noreorder
   .set  nomacro
   #while(r<post) <=> while(r+off<r+n) <=> while(off<n) <=> while((n-off)>0)
   beqz  $t0,  mdct_unroll_lap_post_lap
    add  $s0, $s0, $a2                       # l += off*2;
   .set  macro
   .set  reorder
   lw    $a1, 0($s1)                         # *r
   addi  $s1, $s1, 4                         # r++
   lw    $a0, -4($s2)                        # *--wR
   addi  $s2, $s2, -4
   lw    $t8, 0($s0)                         # *l
   addiu $s0, $s0, 8                         # l+=2
   lw    $t9, 0($s3)                         # *wL
   addiu $t0, $t0, -1
   .set  noreorder
   .set  nomacro
   beqz  $t0,  mdct_unroll_lap_croos_while_loop1_end
    addi $s3, $s3, 4                         # wL++
   .set  macro
   .set  reorder
   li    $v1, 0xFFFFFFFF
mdct_unroll_lap_croos_while_loop1:
   mult  $a1, $a0                            # a1=MULT32(*r++,*--wR)
   mtlo  $v1
   lw    $a1, 0($s1)                         # *r
   shilo $ac0, -1                            # MULT32(*r++,*--wR)
   dpsq_sa.l.w  $ac0, $t8, $t9               # (MULT31(*r++,*--wR) -
                                             #     MULT31(*l,*wL++))
   addi  $s1, $s1, 4                         # r++
   lw    $a0, -4($s2)                        # *--wR
   addi  $s2, $s2, -4
   mfhi  $s7
   lw    $t8, 0($s0)                         # *l
   addiu $s0, $s0, 8                         # l+=2
   lw    $t9, 0($s3)                         # *wL
   addi  $s3, $s3, 4                         # wL++
   sra   $s7, $s7, 9                         # s7=(MULT31(*r++,*--wR) -
                                             #        MULT31(*l,*wL++))>>9
   shll_s.w $s7, $s7, 16                     # *out = CLIP_TO_15((MULT31(*r++,*--wR)
                                             #         - MULT31(*l,*wL++))>>9);
   sra   $s7, $s7, 16
   addiu $t0, $t0, -1
   sh    $s7, 0($t4)
   .set  noreorder
   .set  nomacro
   bnez  $t0,  mdct_unroll_lap_croos_while_loop1
    add  $t4, $t4, $t5                       # out+=step
   .set  macro
   .set  reorder
mdct_unroll_lap_croos_while_loop1_end:
   mult  $a1, $a0                            # a1=MULT31(*r++,*--wR)
   mtlo  $v1
   shilo $ac0, -1                            # MULT32(*r++,*--wR)
   dpsq_sa.l.w  $ac0, $t8, $t9               # (MULT31(*r++,*--wR) -
                                             #     MULT31(*l,*wL++))
   mfhi  $s7
   sra   $s7, $s7, 9                         # s7=(MULT31(*r++,*--wR) -
                                             #        MULT31(*l,*wL++))>>9
   shll_s.w $s7, $s7, 16                     # *out = CLIP_TO_15((MULT31(*r++,*--wR)
                                             #         - MULT31(*l,*wL++))>>9);
   sra   $s7, $s7, 16
   sh    $s7, 0($t4)
   add   $t4, $t4, $t5                       # out+=step

# postLap preceeding direct-copy lapping from previous frame, if any
mdct_unroll_lap_post_lap:
   beqz  $s6,  mdct_unroll_lap_end           # if(postLap)
   move  $t1, $t6                            # t1: off = start;
   slt   $a1, $t6, $s6                       # start<postLap?start:postLap
   movz  $t1, $s6, $a1                       # t1: off
   move  $t0, $t7                            # t0: n= end
   slt   $s7, $t7, $s6                       # end<postLap?end:postLap
   movz  $t0, $s6, $s7                       # t0: n
   sll   $a2, $t1, 3                         # (off*2)*4
   sub   $t0, $t1                            # t0: n - off
   .set  noreorder
   .set  nomacro
   #while(l<post) <=> while(l-off*2<l-n*2) <=> while(off<n)<=> while(0<(n-off))
   beqz  $t0,  mdct_unroll_lap_end
    add  $s0, $s0, $a2                       # l+= off*2;
   lw    $a1,0($s0)                          # *l
   addiu $t0,$t0, -1
   addiu $s0,$s0, 8                          # l+=2
   negu  $a1,$a1                             # -*l
   beqz  $t0,  mdct_unroll_lap_postlap_while_loop_end
    sra  $a2,$a1, 9                          # (-*l)>>9
   .set  macro
   .set  reorder
mdct_unroll_lap_postlap_while_loop:
   lw    $a1, 0($s0)                         # *l
   shll_s.w $a2, $a2, 16
   addiu $t0, $t0, -1
   negu  $a1, $a1                            # -*l
   sra   $a2, $a2,16                         # CLIP_TO_15((-*l)>>9)
   addiu $s0, $s0,8                          # l+=2
   sh    $a2, 0($t4)                         # *out = CLIP_TO_15((-*l)>>9)
   add   $t4, $t4,$t5                        # out+=step
   .set  noreorder
   .set  nomacro
   bnez  $t0,  mdct_unroll_lap_postlap_while_loop
    sra  $a2, $a1,9
   .set  macro
   .set  reorder
mdct_unroll_lap_postlap_while_loop_end:
   shll_s.w $a2, $a2, 16
   sra   $a2, $a2, 16                        # CLIP_TO_15((-*l)>>9)
   sh    $a2, 0($t4)                         # *out = CLIP_TO_15((-*l)>>9)
   add   $t4, $t4, $t5                       # out+=step

mdct_unroll_lap_end:
   lw    $s0, 0($sp)
   lw    $s1, 4($sp)
   lw    $s2, 8($sp)
   lw    $s3, 12($sp)
   lw    $s4, 16($sp)
   lw    $s5, 20($sp)
   lw    $s6, 24($sp)
   lw    $s7, 28($sp)
   addiu $sp, 32
   jr $ra
   .end  mdct_unroll_lap