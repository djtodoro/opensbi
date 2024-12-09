/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 MIPS
 *

Some lines of this code have been copied from
https://github.com/riscv/riscv-tests and are used in accordance with following
license:

Copyright (c) 2012-2015, The Regents of the University of California (Regents).
All Rights Reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of the Regents nor the
   names of its contributors may be used to endorse or promote products
   derived from this software without specific prior written permission.

IN NO EVENT SHALL REGENTS BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING
OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF REGENTS HAS
BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

REGENTS SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE. THE SOFTWARE AND ACCOMPANYING DOCUMENTATION, IF ANY, PROVIDED
HEREUNDER IS PROVIDED "AS IS". REGENTS HAS NO OBLIGATION TO PROVIDE
MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.

*/

#include <sbi/sbi_scratch.h>
#undef MSTATUS_MPRV
#undef SATP_MODE_OFF
#undef SATP_MODE_SV32
#undef SATP_MODE_SV39
#undef SATP_MODE_SV48
#undef SATP_MODE_SV57
#undef SATP_MODE_SV64
#undef MSTATUS_MPV

#define CAUSE_ILLEGAL_INST 2
#define CAUSE_LOAD_ACCESS 0x5
#define CAUSE_STORE_ACCESS 0x7
#define CAUSE_LOAD_PAGE_FAULT 0xd
#define CAUSE_STORE_PAGE_FAULT 0xf
#define CAUSE_GUEST_LOAD_PAGE_FAULT 21
#define CAUSE_GUEST_STORE_PAGE_FAULT 23
#define CAUSE_READ_TIME 26
#define CAUSE_GUEST_TLB_MISS 28
#define MSTATUS_MPRV 0x00020000
#define vsatp 0x280
#define mtval2 0x34b
#define hgatp 0x680

#define SATP_MODE_OFF  0
#define SATP_MODE_SV32 1
#define SATP_MODE_SV39 8
#define SATP_MODE_SV48 9
#define SATP_MODE_SV57 10
#define SATP_MODE_SV64 11
#define mstatus_GVA_LSB 38
#define PTE_V     0x001 /* Valid */
#define PTE_R     0x002 /* Read */
#define PTE_W     0x004 /* Write */
#define PTE_X     0x008 /* Execute */
#define PTE_U     0x010 /* User */
#define PTE_G     0x020 /* Global */
#define PTE_A     0x040 /* Accessed */
#define PTE_D     0x080 /* Dirty */
#define PTE_N     0x8000000000000000 /* Napot */
#define PTE_RSVD  0x7fc0000000000000 /* RSVD */
#define mstatus_MPV_MSB 39
#define mstatus_MPV_LSB 39
#define MSTATUS_MPV ALIGN_FIELD(-1, mstatus_MPV)

/* Return value aligned at [msb:lsb]. */
#define ALIGN(value, msb, lsb) (((value) & ((1 << (1 + msb - lsb)) - 1)) << lsb)

/* Return value aligned at named field, i.e. [<field>_MSB:<field>_LSB]. */
#define ALIGN_FIELD(value, field) ALIGN(value, field##_MSB, field##_LSB)

/* rd = rs[max:min] */
#define extract(rd, rs, max, min)                    ; \
        slli    rd, rs, __riscv_xlen - 1 - max       ; \
        srli    rd, rd, __riscv_xlen - 1 - max + min

/**
 * GPR numbers of named gprs, for passing named gprs to instructon definitions.
 */
#define gpr_idx_x0 0
#define gpr_idx_x1 1
#define gpr_idx_sp 2
#define gpr_idx_gp 3
#define gpr_idx_tp 4
#define gpr_idx_t0 5
#define gpr_idx_t1 6
#define gpr_idx_t2 7
#define gpr_idx_s0 8
#define gpr_idx_fp 8
#define gpr_idx_s1 9
#define gpr_idx_a0 10
#define gpr_idx_a1 11
#define gpr_idx_a2 12
#define gpr_idx_a3 13
#define gpr_idx_a4 14
#define gpr_idx_a5 15
#define gpr_idx_a6 16
#define gpr_idx_a7 17
#define gpr_idx_s2 18
#define gpr_idx_s3 19
#define gpr_idx_s4 20
#define gpr_idx_s5 21
#define gpr_idx_s6 22
#define gpr_idx_s7 23
#define gpr_idx_s8 24
#define gpr_idx_s9 25
#define gpr_idx_s10 26
#define gpr_idx_s11 27
#define gpr_idx_t3 28
#define gpr_idx_t4 29
#define gpr_idx_t5 30
#define gpr_idx_t6 31

#define GPR_IDX(rs) _GPR_IDX(rs)
#define _GPR_IDX(rs) gpr_idx_##rs

#if BIGENDIAN
#define IWORD(x)              ; \
        .byte (x) & 0xff      ; \
        .byte (x)>>8 & 0xff   ; \
        .byte (x)>>16 & 0xff  ; \
        .byte (x)>>24 & 0xff
#else
  #define IWORD(x) .word x
#endif

#define MTLBWR(rs1, level) \
        IWORD(0b11101100000000000000000001110011 | GPR_IDX(rs1)<<15 | level<<20)

#define MTLBWR_HG(rs1, level) \
        IWORD(0b11101100100000000000000001110011 | GPR_IDX(rs1)<<15 | level<<20)

#define PAUSE_ZIHINTPAUSE() \
        IWORD(0b00000001000000000000000000001111)

#define PAUSE_MIPS() \
        IWORD(0b00000000010100000001000000010011)

#if ZIHINTPAUSE
  #define PAUSE() PAUSE_ZIHINTPAUSE()
#else
  #define PAUSE() PAUSE_MIPS()
#endif

#define base (15 << 3) /* This should match SBI_SCRATCH_STW_TMP_OFFSET. */
#if base != SBI_SCRATCH_STW_TMP_OFFSET
  #error WRONG base for STW
#endif
#define O_tmp0 (base + (0 << 3))
#define O_save_x1 (base + (1 << 3))
#define O_satp_vsatp_scratch0 (base + (2 << 3))
#define O_satp_vsatp_scratch1 (base + (3 << 3))
#define O_satp_vsatp_scratch2 (base + (4 << 3))
#define O_satp_vsatp_scratch3 (base + (5 << 3))
#define O_satp_vsatp_scratch4 (base + (6 << 3))
#define O_satp_vsatp_scratch5 (base + (7 << 3))
#define O_satp_vsatp_scratch6 (base + (8 << 3))
#define O_satp_vsatp_scratch7 (base + (9 << 3))
#define O_satp_vsatp_scratch8 (base + (10 << 3))
#define O_hgatp_scratch0 (base + (11 << 3))
#define O_hgatp_scratch1 (base + (12 << 3))
#define O_hgatp_scratch2 (base + (13 << 3))
#define O_hgatp_scratch3 (base + (14 << 3))
#define O_hgatp_scratch4 (base + (15 << 3))
#define O_hgatp_scratch5 (base + (16 << 3))
#define O_amo_scratch (base + (17 << 3)) /* Points to 17 dwords */

#ifdef __riscv_compressed
    #define JUMP_TABLE_SHIFT 2
    #define JUMP_TABLE_OFFSET 4
#else
    #define JUMP_TABLE_SHIFT 3
    #define JUMP_TABLE_OFFSET 8
#endif
