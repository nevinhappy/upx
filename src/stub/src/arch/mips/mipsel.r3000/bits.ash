/*
;  bits.ash -- bit access for decompression
;
;  This file is part of the UCL data compression library.
;
;  Copyright (C) 1996-2006 Markus Franz Xaver Johannes Oberhumer
;  All Rights Reserved.
;
;  The UCL library is free software; you can redistribute it and/or
;  modify it under the terms of the GNU General Public License as
;  published by the Free Software Foundation; either version 2 of
;  the License, or (at your option) any later version.
;
;  The UCL library is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with the UCL library; see the file COPYING.
;  If not, write to the Free Software Foundation, Inc.,
;  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
;
;  Markus F.X.J. Oberhumer              Jens Medoch
;  <markus@oberhumer.com>               <jssg@users.sourceforge.net>
;  http://www.oberhumer.com/opensource/ucl/
;
*/

#ifndef _MR3K_STD_CONF_
#define _MR3K_STD_CONF_


;//////////////////////////////////////
;// register defines
;//////////////////////////////////////

#define tmp         at

#define src         a0
#define dst         a1

#define pc          a2
#define cnt         t0

#define src_ilen    src
#define bb          t0
#define ilen        t1
#define last_m_off  t2
#define m_len       t3
#define bc          t4

#define var         t5
#define m_off       t6
#define m_pos       t6


;//////////////////////////////////////
;// init bitaccess
;//////////////////////////////////////

.macro  UCL_init    bsz,opt,fmcpy

            UCL_NRV_BB = \bsz
            UCL_SMALL = \opt
            UCL_FAST = \fmcpy

            .if ((\bsz != 32) && (\bsz != 8))
                .error "UCL_NRV_BB must be 8 or 32 and not \bsz")
            .else
                PRINT ("\bsz bit, small = \opt, fast memcpy = \fmcpy")
            .endif
            .if (PS1)
                 PRINT ("R3000 code")
            .else
                 PRINT ("R5900 code")
            .endif

.endm


;//////////////////////////////////////
;// init decompressor
;//////////////////////////////////////

.macro  init

            move    bc,zero
            li      last_m_off,1
    .if (src != src_ilen)
            move    src_ilen,src
    .endif

.endm


;//////////////////////////////////////
;// getbit macro
;//////////////////////////////////////

.macro  ADDBITS done

    .if (UCL_SMALL == 1)
            addiu   bc, -1
            bgez    bc, \done
            srlv    var, bb, bc
    .else
            bgtz    bc, \done
            addiu   bc, -1
    .endif

.endm

.macro  ADDBITS_DONE done

    .if (UCL_SMALL == 1)
            srlv    var,bb,bc
\done:
            jr      ra
    .else
\done:
            srlv    var,bb,bc
    .endif
            andi    var,0x0001

.endm

.macro  FILLBYTES_8

            li      bc,7
            lbu     bb,0(src_ilen)
            addiu   src_ilen,1

.endm

.macro  FILLBYTES_32

            li      bc,31
            lwr     bb,0(src_ilen)
            lwl     bb,3(src_ilen)
            addiu   src_ilen,4

.endm

.macro  FILLBYTES

    .if (UCL_NRV_BB == 8)
            FILLBYTES_8
    .else // (UCL_NRV_BB == 32)
            FILLBYTES_32
    .endif

.endm

.macro  GBIT

            local d

            ADDBITS d
            FILLBYTES
            ADDBITS_DONE d

.endm


;//////////////////////////////////////
;// getbit call macro for SMALL version
;//////////////////////////////////////

.macro      GETBIT  p1

    .if (UCL_SMALL == 1)
        .ifb   p1
            bal     1f      // gb_sub
        .else
            bal     1f+4    // gb_sub+4
            addiu   bc,-1
        .endif
    .else
            GBIT
    .endif

.endm


;//////////////////////////////////////
;// getbit call macro for SMALL version
;//////////////////////////////////////

.macro  build   option, type, label

            local   done

.ifc "\option", "full"
.ifnb label
\label:
.endif
            \type   done
.if (UCL_SMALL == 1)
1:
            GBIT
.endif
done:
.else
.ifc "\option", "sub_only"
            sub_size = .
            GBIT
            sub_size = . - sub_size
.else
.ifc "\option", "without_sub"
    .if (UCL_SMALL == 1)
        PRINT ("[WARNING] building \type with UCL_SMALL = 1 without subroutine")
        .if (sub_size != 0)
            \type   decomp_done
1:
        .else
            .error "\"with_no_sub\" cannot build if \"build_sub\" must be used first"
        .endif
    .else
        .error "\"without_sub\" cannot build if UCL_SMALL = 0"
    .endif
.else
    .error "use \"full\", \"sub\" or \"without_sub\" for build"
.endif
.endif
.endif
.endm


;//////////////////////////////////////
;// ucl memcpy
;//////////////////////////////////////

.macro   uclmcpy     ret

            local   wordchk, prepbcpy
            local   bcopy, skip

    .if (UCL_FAST == 1)
            slti    var,m_off,4
            bnez    var,prepbcpy
            subu    m_pos,dst,m_off
wordchk:
            slti    var,m_len,4
            bnez    var,skip
            lwr     var,0(m_pos)
            lwl     var,3(m_pos)
            addiu   m_len,-4
            swr     var,0(dst)
            swl     var,3(dst)
            addiu   m_pos,4
            bnez    m_len,wordchk
            addiu   dst,4
            b       \ret
            nop
prepbcpy:
    .else
            subu    m_pos,dst,m_off
    .endif
bcopy:
            lbu     var,0(m_pos)
skip:
            addiu   m_len,-1
            sb      var,0(dst)
            addiu   m_pos,1
            bnez    m_len,bcopy
            addiu   dst,1
            b       \ret
            nop

.endm

#endif  //_MR3K_STD_CONF_
