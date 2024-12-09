/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 MIPS
 *
 */


//#define STW_TLB_4KB 1
#include <mips/stw.h>
#include <mips/board.h>
#include <mips/p8700.h>

#if defined(__riscv_zbb)
#define ZBB_PRESENT 1
#endif

        .text
        .align  8
        .globl  mipstvec_handler_stw
mipstvec_handler_stw:
        j       mipstvec_handler_stw_not_vec  ; .align 2 /* 0 */
        j       fail                          ; .align 2 /* 1 */
        j       illegal_inst_handler          ; .align 2 /* 2 */
        j       fail                          ; .align 2 /* 3 */
        j       fail                          ; .align 2 /* 4 */
        j       htw_load_access_fault_handler ; .align 2 /* 5 */
        j       fail                          ; .align 2 /* 6 */
        j       fail                          ; .align 2 /* 7 */
        j       fail                          ; .align 2 /* 8 */
        j       fail                          ; .align 2 /* 9 */
        j       fail                          ; .align 2 /* 10 */
        j       fail                          ; .align 2 /* 11 */
        j       fail                          ; .align 2 /* 12 */
        j       fail                          ; .align 2 /* 13 */
        j       fail                          ; .align 2 /* 14 */
        j       fail                          ; .align 2 /* 15 */
        j       fail                          ; .align 2 /* 16 */
        j       fail                          ; .align 2 /* 17 */
        j       fail                          ; .align 2 /* 18 */
        j       fail                          ; .align 2 /* 19 */
        j       fail                          ; .align 2 /* 20 */
        j       htw_page_fault_handler        ; .align 2 /* 21 */
        j       fail                          ; .align 2 /* 22 */
        j       fail                          ; .align 2 /* 23 */
        j       satp_refill_handler           ; .align 2 /* 24 */
        j       satp_refill_handler           ; .align 2 /* 25 */
        j       read_time_handler             ; .align 2 /* 26 */
        j       satp_refill_handler           ; .align 2 /* 27 */
        j       hgatp_refill_handler          ; .align 2 /* 28 */
        j       hgatp_refill_handler          ; .align 2 /* 29 */
        j       read_time_handler             ; .align 2 /* 30 */
        j       hgatp_refill_handler          ; .align 2 /* 31 */

mipstvec_handler_stw_not_vec:
        csrci   CSR_MIPSCONFIG5, MIPSCONFIG5_MTW
        csrrw   sp, mscratch, sp   // Save sp to mscratch, load mscratch to sp
        sd      x1, O_save_x1(sp)  // Save x1 to memory
        csrr    x1, mcause         // Read mcause

#define _mipstvec_handler_dispatch(i)        ; \
        addi    x1, x1, -i                   ; \
        bnez    x1, 10f                      ; \
        ld      x1, O_save_x1(sp)            ; \
        csrrw   sp, mscratch, sp             ; \
        j       mipstvec_handler_stw + 4 * i ; \
10:     addi    x1, x1, i

#define _mipstvec_handler_dispatch_mtw(i)    ; \
        addi    x1, x1, -i                   ; \
        bnez    x1, 10f                      ; \
        ld      x1, O_save_x1(sp)            ; \
        csrrw   sp, mscratch, sp             ; \
        csrsi   CSR_MIPSCONFIG5, MIPSCONFIG5_MTW ; \
        j       mipstvec_handler_stw + 4 * i ; \
10:     addi    x1, x1, i

        _mipstvec_handler_dispatch(2)
        _mipstvec_handler_dispatch(20)
        _mipstvec_handler_dispatch(21)
        _mipstvec_handler_dispatch(23)
        _mipstvec_handler_dispatch(24)
        _mipstvec_handler_dispatch(25)
        _mipstvec_handler_dispatch(26)
        _mipstvec_handler_dispatch(27)
        _mipstvec_handler_dispatch_mtw(28)
        _mipstvec_handler_dispatch_mtw(29)
        _mipstvec_handler_dispatch_mtw(30)
        _mipstvec_handler_dispatch_mtw(31)
        j       fail

satp_refill_handler:
vsatp_refill_handler:
        csrrw	sp, mscratch, sp    /* sp = mscratch; mscratch = saved sp */
        sd      t0, O_satp_vsatp_scratch0(sp) /* save t0 */
        csrrw	t0, mscratch, sp    /* t0 = saved sp; restore mscratch */
        sd      t0, O_satp_vsatp_scratch8(sp) /* save sp */
        sd      t1, O_satp_vsatp_scratch1(sp) /* save t1 */
        sd      t2, O_satp_vsatp_scratch2(sp) /* save t2 */
        sd      t3, O_satp_vsatp_scratch3(sp) /* save t3 */
        sd      s4, O_satp_vsatp_scratch4(sp) /* save s4 */
        sd      t5, O_satp_vsatp_scratch5(sp) /* save t5 */
        sd      t6, O_satp_vsatp_scratch6(sp) /* save t6 */
        sd      s7, O_satp_vsatp_scratch7(sp) /* save s7 */

        /* Save mstatus, mepc (not actually needed for non-vmode refill) */
        csrr    s4, mstatus
        csrr    t5, mepc
        csrrsi  t6, CSR_MIPSCONFIG5, MIPSCONFIG5_MTW  /* set MTW bit */

        /* Only V can be set out of following bits for PTE to be non-leaf */
        li      s7, PTE_V | PTE_R | PTE_W | PTE_X | PTE_U | PTE_A | PTE_D | PTE_N | PTE_RSVD

_read_xsatp:
        /* t1 = vsatp if vmode exception (mstatus.GVA=1) else satp */
        sll     t3, s4, __riscv_xlen - 1 - mstatus_GVA_LSB
        bgez    t3, 1f
        csrr    t3, vsatp
        j       2f
1:      csrr    t3, satp
2:

_find_xsatp_mode:
        slli	t0, t3, 20   // t0 = satp.PPN << 20 (clear out MODE, ASID)
        srli	t0, t0, 8    // "a" = t0 = satp.PPN << 12 (i.e. * PAGESIZE)
        li      t1, 0        // Is this PTE global? (Need to track during walk).
        csrr    t2, mtval    // va

        // Branch according to xsatp.MODE
        srli    t3, t3, 60
        addi    t3, t3, -SATP_MODE_SV39
        beqz	t3, _xsatp_Sv39_level2  // Sv39
        addi    t3, t3, SATP_MODE_SV39 - SATP_MODE_SV48
        beqz    t3, _xsatp_Sv39_level3  // Sv48
        j	fail

_xsatp_Sv39_level3:
        extract (t3, t2, 47, 39) // t3 = VPN[2]
        slli    t3, t3, 3     // t3 = VPN[2] * PTESIZE
        add     t0, t0, t3    // t0 = a + VPN[2] * PTESIZE
        ld      t0, 0(t0)     // t0 = PTE
        and     t3, t0, s7
        xori    t3, t3, PTE_V
        bnez	t3, _xsatp_level3_leaf
        andi    t3, t0, PTE_G
        or      t1, t1, t3
        extract	(t0, t0, 53, 10) // t0 = PTE[53:10]
        slli    t0, t0, 12       // "a" = t0 = PTE[53:10] * PAGESIZE

_xsatp_Sv39_level2:
        extract (t3, t2, 38, 30) // t3 = VPN[2]
        slli    t3, t3, 3     // t3 = VPN[2] * PTESIZE
        add     t0, t0, t3    // t0 = a + VPN[2] * PTESIZE
        ld      t0, 0(t0)     // t0 = PTE
        and     t3, t0, s7
        xori    t3, t3, PTE_V
        bnez	t3, _xsatp_level2_leaf
        andi    t3, t0, PTE_G
        or      t1, t1, t3
        extract	(t0, t0, 53, 10) // t0 = PTE[53:10]
        slli    t0, t0, 12       // "a" = t0 = PTE[53:10] * PAGESIZE

_xsatp_Sv39_level1:
        extract (t3, t2, 29, 21) // t3 = VPN[2]
        slli    t3, t3, 3     // t3 = VPN[2] * PTESIZE
        add     t0, t0, t3    // t0 = a + VPN[2] * PTESIZE
        ld      t0, 0(t0)     // t0 = PTE
        and     t3, t0, s7
        xori    t3, t3, PTE_V
        bnez	t3, _xsatp_level1_leaf
        andi    t3, t0, PTE_G
        or      t1, t1, t3
        extract	(t0, t0, 53, 10) // t0 = PTE[53:10]
        slli    t0, t0, 12       // "a" = t0 = PTE[53:10] * PAGESIZE

_xsatp_Sv39_level0:
        extract (t3, t2, 20, 13) // t3 = VPN[2] (even page)
        slli    t3, t3, 4     // t3 = VPN[2] (even page) * 2 * PTESIZE
        add     t0, t0, t3    // t0 = a + VPN[2] (even page) 2 * PTESIZE
        ld      t3, 0(t0)     // t3 = even PTE
        ld      t0, 8(t0)     // t0 = odd PTE

_xsatp_level0_leaf:
        or      t3, t3, t1    // global if parent table is global
        or      t0, t0, t1    // global if parent table is global
        li      t1, 0x1000    // even/odd bit
        or      t2, t2, t1    // Odd page mtval
        csrw    mtval, t2
        MTLBWR  (t0, 0)       // Write odd PTE to TLB
        csrc    mtval, t1     // Even page mtval
        MTLBWR  (t3, 0)       // Write even PTE to TLB

_xsatp_mret:
        csrw    mstatus, s4 /* Restore mstatus */
        csrw    mepc, t5 /* Restore mepc */
        csrw    CSR_MIPSCONFIG5, t6 /* Restore mipsconfig5 */

        ld      t0, O_satp_vsatp_scratch0(sp) /* restore t0 */
        ld      t1, O_satp_vsatp_scratch1(sp) /* restore t1 */
        ld      t2, O_satp_vsatp_scratch2(sp) /* restore t2 */
        ld      t3, O_satp_vsatp_scratch3(sp) /* restore t3 */
        ld      s4, O_satp_vsatp_scratch4(sp) /* restore s4 */
        ld      t5, O_satp_vsatp_scratch5(sp) /* restore t5 */
        ld      t6, O_satp_vsatp_scratch6(sp) /* restore t6 */
        ld      s7, O_satp_vsatp_scratch7(sp) /* restore sp */
        ld      sp, O_satp_vsatp_scratch8(sp) /* restore sp */

        mret

_xsatp_level1_leaf:
        or      t0, t0, t1    // global if parent table is global
#ifdef STW_TLB_4KB
        extract (t3, t2, 20, 12)
        sll     t3, t3, 10
        or      t0, t0, t3
        csrw    mtval, t2
        MTLBWR  (t0, 0)
#else
        csrw    mtval, t2
        MTLBWR  (t0, 1)
#endif
        j       _xsatp_mret

_xsatp_level2_leaf:
        or      t0, t0, t1    // global if parent table is global
#ifdef STW_TLB_4KB
        extract (t3, t2, 29, 12)
        sll     t3, t3, 10
        or      t0, t0, t3
        csrw    mtval, t2
        MTLBWR  (t0, 0)
#else
        csrw    mtval, t2
        MTLBWR  (t0, 2)
#endif
        j       _xsatp_mret

_xsatp_level3_leaf:
        or      t0, t0, t1    // global if parent table is global
#ifdef STW_TLB_4KB
        extract (t3, t2, 38, 12)
        sll     t3, t3, 10
        or      t0, t0, t3
        csrw    mtval, t2
        MTLBWR  (t0, 0)
#else
        csrw    mtval, t2
        MTLBWR  (t0, 3)
#endif
        j       _xsatp_mret

hgatp_refill_handler:
        csrrw	sp, mscratch, sp    /* sp = mscratch; mscratch = saved sp */
        sd      t0, O_hgatp_scratch0(sp) /* save t0 */
        csrrw	t0, mscratch, sp    /* t0 = saved sp; restore mscratch */
        sd      t0, O_hgatp_scratch5(sp) /* save sp */
        sd      t1, O_hgatp_scratch1(sp) /* save t1 */
        sd      t2, O_hgatp_scratch2(sp) /* save t2 */
        sd      t3, O_hgatp_scratch3(sp) /* save t3 */
        sd      s4, O_hgatp_scratch4(sp) /* save s4 */

        /* Only V can be set out of following bits for PTE to be non-leaf */
        li      s4, PTE_V | PTE_R | PTE_W | PTE_X | PTE_U | PTE_A | PTE_D | PTE_N | PTE_RSVD

        /* set MTW=1 */
        csrsi   CSR_MIPSCONFIG5, MIPSCONFIG5_MTW

_find_hgatp_mode:
        csrr    t3, hgatp
        slli	t0, t3, 20   // t0 = hgatp.PPN << 20 (clear out MODE, ASID)
        srli	t0, t0, 8    // "a" = t0 = hgatp.PPN << 12 (i.e. * PAGESIZE)
        li      t1, 0        // Is this PTE global? (Need to track during walk).
        csrr    t2, mtval    // gpa

        // Branch according to hgatp.MODE
        srli    t3, t3, 60
        addi    t3, t3, -SATP_MODE_SV39
        bnez 	t3, 1f
        extract (t3, t2, 38, 28) // t3 = VPN[2]
        j       _hgatp_Sv39x4_level2_got_vpn2
1:      addi    t3, t3, SATP_MODE_SV39 - SATP_MODE_SV48
        beqz    t3, _hgatp_Sv39x4_level3
        j	fail

_hgatp_Sv39x4_level3:
        extract (t3, t2, 47, 37) // t3 = VPN[2]
        slli    t3, t3, 3     // t3 = VPN[2] * PTESIZE
        add     t0, t0, t3    // t0 = a + VPN[2] * PTESIZE
        ld      t0, 0(t0)     // t0 = PTE
        and     t3, t0, s4
        xori    t3, t3, PTE_V
        bnez	t3, _hgatp_level3_leaf
        andi    t3, t0, PTE_G
        or      t1, t1, t3
        extract	(t0, t0, 53, 10) // t0 = PTE[53:10]
        slli    t0, t0, 12       // "a" = t0 = PTE[53:10] * PAGESIZE

_hgatp_Sv39x4_level2:
        extract (t3, t2, 36, 28) // t3 = VPN[2]
_hgatp_Sv39x4_level2_got_vpn2:
        slli    t3, t3, 3     // t3 = VPN[2] * PTESIZE
        add     t0, t0, t3    // t0 = a + VPN[2] * PTESIZE
        ld      t0, 0(t0)     // t0 = PTE
        and     t3, t0, s4
        xori    t3, t3, PTE_V
        bnez	t3, _hgatp_level2_leaf
        andi    t3, t0, PTE_G
        or      t1, t1, t3
        extract	(t0, t0, 53, 10) // t0 = PTE[53:10]
        slli    t0, t0, 12       // "a" = t0 = PTE[53:10] * PAGESIZE

_hgatp_Sv39x4_level1:
        extract (t3, t2, 27, 19) // t3 = VPN[2]
        slli    t3, t3, 3     // t3 = VPN[2] * PTESIZE
        add     t0, t0, t3    // t0 = a + VPN[2] * PTESIZE
        ld      t0, 0(t0)     // t0 = PTE
        and     t3, t0, s4
        xori    t3, t3, PTE_V
        bnez	t3, _hgatp_level1_leaf
        andi    t3, t0, PTE_G
        or      t1, t1, t3
        extract	(t0, t0, 53, 10) // t0 = PTE[53:10]
        slli    t0, t0, 12       // "a" = t0 = PTE[53:10] * PAGESIZE

_hgatp_Sv39x4_level0:
        extract (t3, t2, 18, 11) // t3 = VPN[2] (even page)
        slli    t3, t3, 4     // t3 = VPN[2] (even page) * 2 * PTESIZE
        add     t0, t0, t3    // t0 = a + VPN[2] (even page) 2 * PTESIZE
        ld      t2, 0(t0)     // t2 = even PTE
        ld      t3, 8(t0)     // t3 = odd PTE

_hgatp_level0_leaf:
        or      t2, t2, t1    // global if parent table is global
        or      t3, t3, t1    // global if parent table is global
        li      t0, 0x0400    // even/odd bit
        csrc    mtval, t0
        MTLBWR_HG (t2, 0)
        csrs    mtval, t0
        MTLBWR_HG (t3, 0)

_hgatp_mret:
        csrci   CSR_MIPSCONFIG5, MIPSCONFIG5_MTW /* Clear MTW bit */

        ld      t0, O_hgatp_scratch0(sp) /* restore t0 */
        ld      t1, O_hgatp_scratch1(sp) /* restore t1 */
        ld      t2, O_hgatp_scratch2(sp) /* restore t2 */
        ld      t3, O_hgatp_scratch3(sp) /* restore t3 */
        ld      s4, O_hgatp_scratch4(sp) /* restore s4 */
        ld      sp, O_hgatp_scratch5(sp) /* restore sp */

        mret

_hgatp_level1_leaf:
        or      t0, t0, t1    // global if parent table is global
#ifdef STW_TLB_4KB
        extract (t3, t2, 20, 12)
        sll     t3, t3, 10
        or      t0, t0, t3
        MTLBWR_HG (t0, 0)
#else
        MTLBWR_HG (t0, 1)
#endif
        j       _hgatp_mret

_hgatp_level2_leaf:
        or      t0, t0, t1    // global if parent table is global
#ifdef STW_TLB_4KB
        extract (t3, t2, 29, 12)
        sll     t3, t3, 10
        or      t0, t0, t3
        MTLBWR_HG (t0, 0)
#else
        MTLBWR_HG (t0, 2)
#endif
        j       _hgatp_mret

_hgatp_level3_leaf:
        or      t0, t0, t1    // global if parent table is global
#ifdef STW_TLB_4KB
        extract (t3, t2, 38, 12)
        sll     t3, t3, 10
        or      t0, t0, t3
        MTLBWR_HG (t0, 0)
#else
        MTLBWR_HG (t0, 3)
#endif
        j       _hgatp_mret

htw_load_access_fault_handler:
htw_hgatp_refill_handler:
htw_page_fault_handler:
        j       fail



/********************
 * rdtime emulation *
 ********************/
        .global read_time_handler
read_time_handler:
        csrrw	sp, mscratch, sp    /* sp = mscratch; mscratch = saved sp */
        sd      x1, O_satp_vsatp_scratch0(sp) /* save sp */
        sd      x3, O_satp_vsatp_scratch1(sp) /* save x3 */

        /* Set x1 to address of function which will set rd to x3 */
        csrr    x1, mtval
        srli    x1, x1, 7 - JUMP_TABLE_SHIFT
        andi    x1, x1, 0x1f << JUMP_TABLE_SHIFT
        lla     x3, write_xr_rdtime
        add     x1, x1, x3

        /* Read the time memory mapped register */
        lui     x3, %hi(TIMER_ADDR)
        ld      x3, %lo(TIMER_ADDR)(x3)

        /* Call function which sets rd = x3 */
        jalr    x1

        /* Increment mepc to skip instruction we just emulated */
        csrr    x1, mepc
        addi    x1, x1, 4
        csrw    mepc, x1

        /* Restore gprs from memory */
        ld      x1, O_satp_vsatp_scratch0(sp) /* restore x1 */
        ld      x3, O_satp_vsatp_scratch1(sp) /* restore x3 */
        csrrw	sp, mscratch, sp

        mret

/***************************************
 * Custom Illegal Instruction handling *
 ***************************************/

illegal_inst_handler:
        csrrw	sp, mscratch, sp    /* sp = mscratch; mscratch = saved sp */
        sd      x1, (O_amo_scratch + 0 * 8)(sp)
        csrrw	x1, mscratch, sp    /* x1 = saved sp; restore mscratch */
        sd      x1, (O_amo_scratch + 1 * 8)(sp) /* save sp */
        sd      x3, (O_amo_scratch + 2 * 8)(sp)
        sd      x4, (O_amo_scratch + 3 * 8)(sp)
        sd      x5, (O_amo_scratch + 4 * 8)(sp)
        sd      x6, (O_amo_scratch + 5 * 8)(sp)
        sd      x7, (O_amo_scratch + 6 * 8)(sp)
        sd      x8, (O_amo_scratch + 7 * 8)(sp)
        sd      x9, (O_amo_scratch + 8 * 8)(sp)
        sd      x10, (O_amo_scratch + 9 * 8)(sp)

// Planned register use:
//   x1 - ra, temporary, result
//   x2 - sp
//   x3 - rs1 value
//   x4 - rs2 value
//   x5 - temporary (mtval, mtval_match)
//   x6 - saved mepc
//   x7 - saved mtvec
//   x8 - saved mstatus
//   x9 - saved mtval
//   x10 - temporary (fail count)

        csrr    x9, mtval  // x9 = faulting opcode

        /* x3 = rs1 value */
        lla     x7, read_xr_amo  // x7 = base address of table of read_xr funcs
        srli    x6, x9, 15 - JUMP_TABLE_SHIFT  // Align rs1 idx as table offset
        andi    x6, x6, 0x1f << JUMP_TABLE_SHIFT  // Isolated aligned rs1
        add     x4, x6, x7       // Apply offset to jump table
        jalr    x4               // Call func to read rs1 into x4
        move    x3, x4           // x3 = rs1 value

        /* x4 = rs2 value */
        srli    x6, x9, 20 - JUMP_TABLE_SHIFT  // Align rs2 idx as table offset
        andi    x6, x6, 0x1f << JUMP_TABLE_SHIFT  // Isolate aligned rs2
        add     x4, x6, x7       // Apply offset to jump table
        jalr    x4               // Call func to read rs1 into x4

        /* x6 = saved epc */
        csrr    x6, mepc  // Save mepc

        /* Use a local handler for mtvec exceptions */
        lla     x1, _illegal_inst_mtvec_handler
        csrrw   x7, mtvec, x1 // x7 = saved mtvec

        /*
         * Extract the AMO opcode match bits, write that value to t5. Each AMO
         * instruction has a single unique value for these match bits. Since
         * every AMO has the same value for the lower 12 bits, we xor the
         * match value with the value of those lower 12 bits. This allows us
         * to construct the compare value for each AMO instruction using a
         * single LUI instruction.
         */
        li      x1, 0b11111000000000000111000001111111
        and     x5, x9, x1
        xori    x5, x5, 0b000000101111

        li      x1, 0b00000000000000000010000000000000
        beq     x5, x1, _illegal_inst_handler_amoadd_w

        li      x1, 0b00000000000000000011000000000000
        beq     x5, x1, _illegal_inst_handler_amoadd_d

        li      x1, 0b01100000000000000010000000000000
        beq     x5, x1, _illegal_inst_handler_amoand_w

        li      x1, 0b01100000000000000011000000000000
        beq     x5, x1, _illegal_inst_handler_amoand_d

        li      x1, 0b10100000000000000010000000000000
        beq     x5, x1, _illegal_inst_handler_amomax_w

        li      x1, 0b10100000000000000011000000000000
        beq     x5, x1, _illegal_inst_handler_amomax_d

        li      x1, 0b11100000000000000010000000000000
        beq     x5, x1, _illegal_inst_handler_amomaxu_w

        li      x1, 0b11100000000000000011000000000000
        beq     x5, x1, _illegal_inst_handler_amomaxu_d

        li      x1, 0b10000000000000000010000000000000
        beq     x5, x1, _illegal_inst_handler_amomin_w

        li      x1, 0b10000000000000000011000000000000
        beq     x5, x1, _illegal_inst_handler_amomin_d

        li      x1, 0b11000000000000000010000000000000
        beq     x5, x1, _illegal_inst_handler_amominu_w

        li      x1, 0b11000000000000000011000000000000
        beq     x5, x1, _illegal_inst_handler_amominu_d

        li      x1, 0b01000000000000000010000000000000
        beq     x5, x1, _illegal_inst_handler_amoor_w

        li      x1, 0b01000000000000000011000000000000
        beq     x5, x1, _illegal_inst_handler_amoor_d

        li      x1, 0b00001000000000000010000000000000
        beq     x5, x1, _illegal_inst_handler_amoswap_w

        li      x1, 0b00001000000000000011000000000000
        beq     x5, x1, _illegal_inst_handler_amoswap_d

        li      x1, 0b00100000000000000010000000000000
        beq     x5, x1, _illegal_inst_handler_amoxor_w

        li      x1, 0b00100000000000000011000000000000
        beq     x5, x1, _illegal_inst_handler_amoxor_d

        j       fail

/**
 * Input:
 *    x3 = rs1
 *    x4 = rs2
 * Ouput:
 *    x5 = old memory value
 *
 * Try LR/SC while counting down from NUM_TRIES_WITHOUT_LOCK to 0.
 * If counter reaches 0, acquire the global lock, then repeat LR/SC,
 * counting down from NUM_TRIES_WITHOUT_LOCK + NUM_TRIES_WITH_LOCK to
 * NUM_TRIES_WITHOUT_LOCK + 1
 * If counter reaches NUM_TRIES_WITHOUT_LOCK + 1 then fail completely.
 * On LR/SC success, if counter > NUM_TRIES_WITHOUT_LOCK then we had the lock,
 * and need to release it.
 *
 * Pseudocode:
 *
 * # Wait until not locked.
 * while locked:
 *     pass
 *
 * counter = NUM_TRIES_WITHOUT_LOCK
 * while 1:
 *     value, fail = amo()
 *     if fail:  # SC fail.
 *         counter -= NUM_TRIES_WITHOUT_LOCK + 1
 *         if counter == 0:
 *             fail
 *         counter += NUM_TRIES_WITHOUT_LOCK
 *         if counter == 0:
 *             get_lock()
 *             counter = NUM_TRIES_WITH_LOCK + NUM_TRIES_WITHOUT_LOCK
 *     else:  # SC pass.
 *         counter -= NUM_TRIES_WITH_LOCK
 *         if counter > 0:
 *             free_lock()
 *         return
 */

#define NUM_TRIES_WITHOUT_LOCK 20
#define NUM_TRIES_WITH_LOCK 10000
//#define NO_AMO_EMULATION_LOCK 1

#if NO_AMO_EMULATION_LOCK
#define DO_AMO(SIZE, AMO_OPERATION...)                            ; \
        /* Set mstatus.MPRV = 1, x8 = saved mstatus */            ; \
25:     li      x8, MSTATUS_MPRV                                  ; \
        csrrs   x8, mstatus, x8                                   ; \
                                                                  ; \
30:     lr.SIZE.aq x5, (x3)                                       ; \
        AMO_OPERATION                                             ; \
        sc.SIZE.aqrl x1, x1, (x3)                                 ; \
        beqz    x1, _illegal_inst_handler_return                  ; \
        j       30b
#else
#define DO_AMO(SIZE, AMO_OPERATION...)                            ; \
        /* Wait until lock is clear */                            ; \
        lla     x10, amo_lock                                     ; \
10:     lr.d    x5, (x10)                                         ; \
        beqz    x5, 20f                                           ; \
        PAUSE()                                                   ; \
        j       10b                                               ; \
                                                                  ; \
20:     li      x10, NUM_TRIES_WITHOUT_LOCK                       ; \
                                                                  ; \
        /* Set mstatus.MPRV = 1, x8 = saved mstatus */            ; \
25:     li      x8, MSTATUS_MPRV                                  ; \
        csrrs   x8, mstatus, x8                                   ; \
                                                                  ; \
30:     lr.SIZE.aq x5, (x3)                                       ; \
        AMO_OPERATION                                             ; \
        sc.SIZE.aqrl x1, x1, (x3)                                 ; \
        beqz    x1, _illegal_inst_handler_return                  ; \
        /* SC failed */                                           ; \
        addi    x10, x10, -NUM_TRIES_WITHOUT_LOCK + 1             ; \
        bnez    x10, 40f                                          ; \
        csrw    mstatus, x8                                       ; \
        j       fail                                              ; \
40:     addi    x10, x10, NUM_TRIES_WITHOUT_LOCK                  ; \
        bnez    x10, 30b                                          ; \
                                                                  ; \
        /* Acquire lock */                                        ; \
        csrw    mstatus, x8                                       ; \
        lla     x10, amo_lock                                     ; \
50:     lr.d    x5, (x10)                                         ; \
        beqz    x5, 60f                                           ; \
        PAUSE()                                                   ; \
        j       50b                                               ; \
60:     sc.d    x5, sp, (x10) /* Use sp as lock value */          ; \
        bnez    x5, 50b                                           ; \
                                                                  ; \
        /* Retry with lock */                                     ; \
        li      x10, NUM_TRIES_WITH_LOCK + NUM_TRIES_WITHOUT_LOCK ; \
        j       25b
#endif  /* NO_AMO_EMULATION_LOCK */

_illegal_inst_handler_amoadd_w:
        DO_AMO(w, addw    x1, x5, x4)

_illegal_inst_handler_amoadd_d:
        DO_AMO(d, add     x1, x5, x4)

_illegal_inst_handler_amoand_w:
        DO_AMO(w, and     x1, x5, x4)

_illegal_inst_handler_amoand_d:
        DO_AMO(d, and     x1, x5, x4)

_illegal_inst_handler_amomax_w:
        addw    x4, x4, x0
#if ZBB_PRESENT
        DO_AMO(w, max     x1, x5, x4)
#else
        DO_AMO(w,
        move    x1, x5          ;
        bge     x5, x4, 5f      ;
        move    x1, x4          ;
5:
        )
#endif

_illegal_inst_handler_amomax_d:
#if ZBB_PRESENT
        DO_AMO(d, max     x1, x5, x4)
#else
        DO_AMO(d,
        move    x1, x5          ;
        bge     x5, x4, 5f      ;
        move    x1, x4          ;
5:
        )
#endif

_illegal_inst_handler_amomaxu_w:
        addw    x4, x4, x0
#if ZBB_PRESENT
        DO_AMO(w, maxu    x1, x5, x4)
#else
        DO_AMO(w,
        move    x1, x5          ;
        bgeu    x5, x4, 5f      ;
        move    x1, x4          ;
5:
        )
#endif

_illegal_inst_handler_amomaxu_d:
#if ZBB_PRESENT
        DO_AMO(d, maxu    x1, x5, x4)
#else
        DO_AMO(d,
        move    x1, x5          ;
        bgeu    x5, x4, 5f      ;
        move    x1, x4          ;
5:
        )
#endif

_illegal_inst_handler_amomin_w:
        addw    x4, x4, x0
#if ZBB_PRESENT
        DO_AMO(w, min     x1, x5, x4)
#else
        DO_AMO(w,
        move    x1, x5          ;
        ble     x5, x4, 5f      ;
        move    x1, x4          ;
5:
        )
#endif

_illegal_inst_handler_amomin_d:
#if ZBB_PRESENT
        DO_AMO(d, min     x1, x5, x4)
#else
        DO_AMO(d,
        move    x1, x5          ;
        ble     x5, x4, 5f      ;
        move    x1, x4          ;
5:
        )
#endif

_illegal_inst_handler_amominu_w:
        addw    x4, x4, x0
#if ZBB_PRESENT
        DO_AMO(w, minu    x1, x5, x4)
#else
        DO_AMO(w,
        move    x1, x5          ;
        bleu    x5, x4, 5f      ;
        move    x1, x4          ;
5:
        )
#endif

_illegal_inst_handler_amominu_d:
#if ZBB_PRESENT
        DO_AMO(d, minu    x1, x5, x4)
#else
        DO_AMO(d,
        move    x1, x5          ;
        bleu    x5, x4, 5f      ;
        move    x1, x4          ;
5:
        )
#endif

_illegal_inst_handler_amoor_w:
        DO_AMO(w, or      x1, x5, x4)

_illegal_inst_handler_amoor_d:
        DO_AMO(d, or      x1, x5, x4)

_illegal_inst_handler_amoswap_w:
        DO_AMO(w, move x1, x4)

_illegal_inst_handler_amoswap_d:
        DO_AMO(d, move x1, x4)

_illegal_inst_handler_amoxor_w:
        DO_AMO(w, xor     x1, x5, x4)

_illegal_inst_handler_amoxor_d:
        DO_AMO(d, xor     x1, x5, x4)

_illegal_inst_handler_return:
        csrw    mstatus, x8 // Restore mstatus (undo MPRV)

#if NO_AMO_EMULATION_LOCK
#else
        /* Clear amo_lock if we had acquired it. */
        addi    x10, x10, -NUM_TRIES_WITHOUT_LOCK
        blez    x10, 10f
        lla     x10, amo_lock
        sd      x0, (x10)
10:
#endif  /* NO_AMO_EMULATION_LOCK */

        /* write rd with value in x5 */
        lla     x4, write_xr_amo  // x4 = base address of write_xr funcs
        srli    x3, x9, 7 - JUMP_TABLE_SHIFT  // Align rd idx as table offset
        andi    x3, x3, 0x1f << JUMP_TABLE_SHIFT  // Isolate aligned rd
        add     x1, x4, x3             // Apply offset to jump table
        jalr    x1                     // Call func to write x5 to rd

        addi    x6, x6, 4  // Saved mepc += 4 (skip emulated instruction)

_illegal_inst_handler_mret:
        csrw    mepc, x6  // Restore mepc
        csrw    mtvec, x7  // Restore mtvec

        /* Restore working set of XRs */
        ld      x1, (O_amo_scratch + 0 * 8)(sp)
        ld      x3, (O_amo_scratch + 2 * 8)(sp)
        ld      x4, (O_amo_scratch + 3 * 8)(sp)
        ld      x5, (O_amo_scratch + 4 * 8)(sp)
        ld      x6, (O_amo_scratch + 5 * 8)(sp)
        ld      x7, (O_amo_scratch + 6 * 8)(sp)
        ld      x8, (O_amo_scratch + 7 * 8)(sp)
        ld      x9, (O_amo_scratch + 8 * 8)(sp)
        ld      x10, (O_amo_scratch + 9 * 8)(sp)
        ld      sp, (O_amo_scratch + 1 * 8)(sp) /* restore sp last */

        mret // Return

        .align  2
_illegal_inst_mtvec_handler:
        /*
         * If any exception occurs on a load/store during AMO emulation,
         * just re-execute the original faulting AMO. This will regenerate
         * the exception (page fault, access fault) and allow it to
         * be handled as though from the original context
         */
        csrw    mstatus, x8 // Restore mstatus

        csrr    x5, mcause

        li      x1, CAUSE_LOAD_PAGE_FAULT
        beq     x5, x1, _illegal_inst_handler_mret

        li      x1, CAUSE_STORE_PAGE_FAULT
        beq     x5, x1, _illegal_inst_handler_mret

        li      x1, CAUSE_GUEST_LOAD_PAGE_FAULT
        beq     x5, x1, _illegal_inst_handler_mret

        li      x1, CAUSE_GUEST_STORE_PAGE_FAULT
        beq     x5, x1, _illegal_inst_handler_mret

        li      x1, CAUSE_LOAD_ACCESS
        beq     x5, x1, _illegal_inst_handler_mret

        li      x1, CAUSE_STORE_ACCESS
        beq     x5, x1, _illegal_inst_handler_mret

        // An unexpected exception during AMO emulation is fatal.
        j       fail

/**
 * This is a table of 32 functions.
 * Calling the function read_xr_amo + rd * JUMP_TABLE_OFFSET does
 * x4 = XR[rd]. For xrs where the value is stored in memory by the AMO handler,
 * do x4 = MEM[address where $rd is stored], which has the equivalent effect.
 */
read_xr_amo:
        li      x4, 0                           ; jr ra
        ld      x4, (O_amo_scratch + 0 * 8)(sp) ; jr ra
        ld      x4, (O_amo_scratch + 1 * 8)(sp) ; jr ra
        ld      x4, (O_amo_scratch + 2 * 8)(sp) ; jr ra
        ld      x4, (O_amo_scratch + 3 * 8)(sp) ; jr ra
        ld      x4, (O_amo_scratch + 4 * 8)(sp) ; jr ra
        ld      x4, (O_amo_scratch + 5 * 8)(sp) ; jr ra
        ld      x4, (O_amo_scratch + 6 * 8)(sp) ; jr ra
        ld      x4, (O_amo_scratch + 7 * 8)(sp) ; jr ra
        ld      x4, (O_amo_scratch + 8 * 8)(sp) ; jr ra
        ld      x4, (O_amo_scratch + 9 * 8)(sp) ; jr ra
        move    x4, x11                         ; jr ra
        move    x4, x12                         ; jr ra
        move    x4, x13                         ; jr ra
        move    x4, x14                         ; jr ra
        move    x4, x15                         ; jr ra
        move    x4, x16                         ; jr ra
        move    x4, x17                         ; jr ra
        move    x4, x18                         ; jr ra
        move    x4, x19                         ; jr ra
        move    x4, x20                         ; jr ra
        move    x4, x21                         ; jr ra
        move    x4, x22                         ; jr ra
        move    x4, x23                         ; jr ra
        move    x4, x24                         ; jr ra
        move    x4, x25                         ; jr ra
        move    x4, x26                         ; jr ra
        move    x4, x27                         ; jr ra
        move    x4, x28                         ; jr ra
        move    x4, x29                         ; jr ra
        move    x4, x30                         ; jr ra
        move    x4, x31                         ; jr ra

/**
 * This is a table of 32 functions.
 * Calling the function write_xr_amo + rd * JUMP_TABLE_OFFSET does:
 * XR[rd] = x5. For xrs which will be restored from memory at the end of
 * the AMO handler, do MEM[address where $rd is stored] = x5.
 */
write_xr_amo:
        jr      ra                              ; jr ra
        sd      x5, (O_amo_scratch + 0 * 8)(sp) ; jr ra
        sd      x5, (O_amo_scratch + 1 * 8)(sp) ; jr ra
        sd      x5, (O_amo_scratch + 2 * 8)(sp) ; jr ra
        sd      x5, (O_amo_scratch + 3 * 8)(sp) ; jr ra
        sd      x5, (O_amo_scratch + 4 * 8)(sp) ; jr ra
        sd      x5, (O_amo_scratch + 5 * 8)(sp) ; jr ra
        sd      x5, (O_amo_scratch + 6 * 8)(sp) ; jr ra
        sd      x5, (O_amo_scratch + 7 * 8)(sp) ; jr ra
        sd      x5, (O_amo_scratch + 8 * 8)(sp) ; jr ra
        sd      x5, (O_amo_scratch + 9 * 8)(sp) ; jr ra
        move    x11, x5                         ; jr ra
        move    x12, x5                         ; jr ra
        move    x13, x5                         ; jr ra
        move    x14, x5                         ; jr ra
        move    x15, x5                         ; jr ra
        move    x16, x5                         ; jr ra
        move    x17, x5                         ; jr ra
        move    x18, x5                         ; jr ra
        move    x19, x5                         ; jr ra
        move    x20, x5                         ; jr ra
        move    x21, x5                         ; jr ra
        move    x22, x5                         ; jr ra
        move    x23, x5                         ; jr ra
        move    x24, x5                         ; jr ra
        move    x25, x5                         ; jr ra
        move    x26, x5                         ; jr ra
        move    x27, x5                         ; jr ra
        move    x28, x5                         ; jr ra
        move    x29, x5                         ; jr ra
        move    x30, x5                         ; jr ra
        move    x31, x5                         ; jr ra

/**
 * This is a table of 32 functions.
 * Calling the function write_xr_rdtime + rd * JUMP_TABLE_OFFSET does:
 * XR[rd] = x3. For xrs which will be restored from memory at the end of
 * the rdtime handler, do MEM[address where $rd is stored] = x3.
 */
write_xr_rdtime:
        jr      ra                            ; jr ra
        sd      x3, O_satp_vsatp_scratch0(sp) ; jr ra
        j       _write_xr_rdtime_x1           ; jr ra
        sd      x3, O_satp_vsatp_scratch1(sp) ; jr ra
        move    x4, x3                        ; jr ra
        move    x5, x3                        ; jr ra
        move    x6, x3                        ; jr ra
        move    x7, x3                        ; jr ra
        move    x8, x3                        ; jr ra
        move    x9, x3                        ; jr ra
        move    x10, x3                       ; jr ra
        move    x11, x3                       ; jr ra
        move    x12, x3                       ; jr ra
        move    x13, x3                       ; jr ra
        move    x14, x3                       ; jr ra
        move    x15, x3                       ; jr ra
        move    x16, x3                       ; jr ra
        move    x17, x3                       ; jr ra
        move    x18, x3                       ; jr ra
        move    x19, x3                       ; jr ra
        move    x20, x3                       ; jr ra
        move    x21, x3                       ; jr ra
        move    x22, x3                       ; jr ra
        move    x23, x3                       ; jr ra
        move    x24, x3                       ; jr ra
        move    x25, x3                       ; jr ra
        move    x26, x3                       ; jr ra
        move    x27, x3                       ; jr ra
        move    x28, x3                       ; jr ra
        move    x29, x3                       ; jr ra
        move    x30, x3                       ; jr ra
        move    x31, x3                       ; jr ra
_write_xr_rdtime_x1:
        csrw    mscratch, x3                  ; jr ra

fail:
        unimp

	.section .sbss
	.align  6
	.type   amo_lock, @object
	.size   amo_lock, 64
amo_lock:
        .zero   64
