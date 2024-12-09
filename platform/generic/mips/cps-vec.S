/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2024 MIPS
 *
 */

#include <sbi/riscv_encoding.h>
#include <mips/p8700.h>

	.text
	.align	12
	.globl	mips_cps_core_entry
mips_cps_core_entry:
	j	1f

	.align	2
nmi_vector:
	j	1f

	.align	2
cacheerr_vector:
	j	1f

	.align	2
debugexc_vector:
	j	1f

	.align	2
1:
	li	x1, 0
	li	x2, 0
	li	x3, 0
	li	x4, 0
	li	x5, 0
	li	x6, 0
	li	x7, 0
	li	x8, 0
	li	x9, 0
	li	x10, 0
	li	x11, 0
	li	x12, 0
	li	x13, 0
	li	x14, 0
	li	x15, 0
	li	x16, 0
	li	x17, 0
	li	x18, 0
	li	x19, 0
	li	x20, 0
	li	x21, 0
	li	x22, 0
	li	x23, 0
	li	x24, 0
	li	x25, 0
	li	x26, 0
	li	x27, 0
	li	x28, 0
	li	x29, 0
	li	x30, 0
	li	x31, 0

	/* a0 has mhartid */
	csrr	a0, CSR_MHARTID

	/* Test mhartid lowest 4 bits */
	andi	t0, a0, 0xf
	bnez	t0, setup_pmp

	/* Cluster cl Core co Hart 0 */
	li	s0, CM_BASE

cm_relocate_done:
	li	t0, GCR_CORE_COH_EN_EN

	/* Get core number to update CM_BASE */
	srl	t1, a0, MHARTID_CORE_SHIFT
	andi	t1, t1, MHARTID_CORE_MASK
	sll	t1, t1, CM_BASE_CORE_SHIFT
	add	s0, s0, t1
	INDEXED(sd, t0, t1, GCR_OFF_LOCAL + GCR_CORE_COH_EN, s0)
	fence

setup_pmp:
	li	t0, DRAM_PMP_ADDR
	csrw	CSR_PMPADDR14, t0
	li	t0, 0x1fffffffffffffff # All from 0x0
	csrw	CSR_PMPADDR15, t0
	li	t0, ((PMP_A_NAPOT|PMP_R|PMP_W|PMP_X)<<56)|((PMP_A_NAPOT|PMP_R|PMP_W|PMP_X)<<48)
	csrw	CSR_PMPCFG2, t0
	/* Set cacheable for pmp6, uncacheable for pmp7 */
	li	t0, (CCA_CACHE_DISABLE << 56)|(CCA_CACHE_ENABLE << 48)
	csrw	CSR_PMACFG2, t0
	/* Reset pmpcfg0 */
	csrw	CSR_PMPCFG0, zero
	/* Reset pmacfg0 */
	csrw	CSR_PMACFG0, zero
	fence

per_cluster:
	li	t0, 0xffff
	and	t0, t0, a0
	bnez	t0, per_core

	/* L2 Prefetch */
	li	t0, 0xfffff110
	sw	t0, L2_PFT_CONTROL_OFFSET(s0)
	li	t0, 0x15ff
	sw	t0, L2_PFT_CONTROL_B_OFFSET(s0)

per_core:
	andi	t0, a0, 0xf
	bnez	t0, per_hart

	/* Enable Load Pair */
	/* Enable Store Pair */
	/* Enable HTW */
	li      t0, (1<<12)|(1<<13)|(1<<7)
	csrc    CSR_MIPSCONFIG7, t0

	/* Disable noRFO */
	li	t0, (1<<25)
	csrs	CSR_MIPSCONFIG7, t0

	/* Disable misaligned load/store to have misaligned address exceptions */
	li	t0, (1<<9)
	csrs	CSR_MIPSCONFIG7, t0

	/* Enable L1-D$ Prefetch */
	li	t0, 0xff
	csrw	CSR_MIPSCONFIG11, t0

	li	t0, 4
	csrs	CSR_MIPSCONFIG8, t0
	li	t0, 8
	csrs	CSR_MIPSCONFIG9, t0
	fence
	fence.i

	li	t0, 0x104
	csrs	CSR_MIPSCONFIG8, t0
	li	t0, 8
	csrs	CSR_MIPSCONFIG9, t0
	fence
	fence.i

	li	t0, 0x204
	csrs	CSR_MIPSCONFIG8, t0
	li	t0, 8
	csrs	CSR_MIPSCONFIG9, t0
	fence
	fence.i

	li	t0, 0x304
	csrs	CSR_MIPSCONFIG8, t0
	li	t0, 8
	csrs	CSR_MIPSCONFIG9, t0
	fence
	fence.i

	li	t0, 0x404
	csrs	CSR_MIPSCONFIG8, t0
	li	t0, 8
	csrs	CSR_MIPSCONFIG9, t0
	fence
	fence.i

	li	t0, 0x504
	csrs	CSR_MIPSCONFIG8, t0
	li	t0, 8
	csrs	CSR_MIPSCONFIG9, t0
	fence
	fence.i

	li	t0, 0x604
	csrs	CSR_MIPSCONFIG8, t0
	li	t0, 8
	csrs	CSR_MIPSCONFIG9, t0
	fence
	fence.i

	li	t0, 0x704
	csrs	CSR_MIPSCONFIG8, t0
	li	t0, 8
	csrs	CSR_MIPSCONFIG9, t0
	fence
	fence.i

per_hart:
	/* Set up mipstvec */
	lla	t0, mipstvec_handler_stw
	ori	t0, t0, 1
	csrw	CSR_MIPSTVEC, t0

	/* Let hart 0 jump to _start */
	beqz	a0, 1f
	lla	t0, _start_warm
	jr	t0
1:
	lla	t0, _start
	jr	t0

