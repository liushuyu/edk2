///** @file
//
//  This code provides low level routines that support the Virtual Machine
//  for option ROMs.
//
//  Copyright (c) 2016, Linaro, Ltd. All rights reserved.<BR>
//  Copyright (c) 2015, The Linux Foundation. All rights reserved.<BR>
//  Copyright (c) 2007 - 2014, Intel Corporation. All rights reserved.<BR>
//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//
//**/

ASM_GLOBAL ASM_PFX(EbcLLCALLEXNative)

ASM_GLOBAL ASM_PFX(mEbcInstructionBufferTemplate)

//****************************************************************************
// EbcLLCALLEX
//
// This function is called to execute an EBC CALLEX instruction.
// This instruction requires that we thunk out to external native
// code. For LoongArch64, we copy the VM stack into the main stack and then pop
// the first 8 arguments off according to the LoongArch64 Procedure Call Standard
// On return, we restore the stack pointer to its original location.
//
//****************************************************************************
// UINTN EbcLLCALLEXNative(UINTN FuncAddr, UINTN NewStackPointer, VOID *FramePtr)
ASM_PFX(EbcLLCALLEXNative):
    move    $t0, $a0                // Preserve a0
    move    $t1, $a1                // Preserve a1

    //
    // If the EBC stack frame is smaller than or equal to 64 bytes, we know there
    // are no stacked arguments #9 and beyond that we need to copy to the native
    // stack. In this case, we can perform a tail call which is much more
    // efficient, since there is no need to touch the native stack at all.
    //
    sub.d   $t2, $a1, $a2           // Length = NewStackPointer - FramePtr
    addi.d  $t3, $r0, 64
    bgt     $t2, $t3, 1f

    //
    // While probably harmless in practice, we should not access the VM stack
    // outside of the interval [NewStackPointer, FramePtr), which means we
    // should not blindly fill all 8 argument registers with VM stack data.
    // So instead, calculate how many argument registers we can fill based on
    // the size of the VM stack frame, and skip the remaining ones.
    //
    la.local        $t4, 0f         // Take address of 'br' instruction below
    bstrins.d       $t2, $r0, 3, 0  // Ensure correct alignment
    srli.d          $t2, $t2, 1     // Subtract 4 bytes for each arg to unstack
    sub.d           $t4, $t4, $t2
    jr              $t4             // Skip remaining argument registers

    ld.d    $a7, $t1, 56
    ld.d    $a6, $t1, 48
    ld.d    $a5, $t1, 40
    ld.d    $a4, $t1, 32
    ld.d    $a3, $t1, 24
    ld.d    $a2, $t1, 16
    ld.d    $a1, $t1, 8
    ld.d    $a0, $t1, 0

0:  jr      $t0                      // Call with no arguments

    //
    // More than 64 bytes: we need to build the full native stack frame and copy
    // the part of the VM stack exceeding 64 bytes (which may contain stacked
    // arguments) to the native stack
    //
1:  move    $t6, $sp

    //
    // Ensure that the stack pointer remains 16 byte aligned,
    // even if the size of the VM stack frame is not a multiple of 16
    //
    addi.d  $a1, $a1, 64            // Skip over [potential] reg params
    andi    $t4, $t2, 15
    beqz    $t4, 2f                 // Multiple of 16?
    ld.d    $t4, $a2, -8            // No? Then push one word
    st.d    $t4, $sp, -16           // ... but use two slots
    b       3f

2:  ld.d    $t4, $a2, -8
    ld.d    $t5, $a2, -16
    st.d    $t4, $sp, -8
    st.d    $t5, $sp, -16
    addi.d  $sp, $sp, -16
3:  bgt     $a2, $a1, 2b

    ld.d    $a0, $t1, 0
    ld.d    $a1, $t1, 8
    ld.d    $a2, $t1, 16
    ld.d    $a3, $t1, 24
    ld.d    $a4, $t1, 32
    ld.d    $a5, $t1, 40
    ld.d    $a6, $t1, 48
    ld.d    $a7, $t1, 56

    jirl    $ra, $t0, 0

    move    $sp, $t6
    ret

//****************************************************************************
// mEbcInstructionBufferTemplate
//****************************************************************************
    .section    ".rodata", "a"
    .align      3
ASM_PFX(mEbcInstructionBufferTemplate):
    la.local $t7, 0f
    ldptr.d  $t8, $t7, 0
    ldptr.d  $t7, $t7, 8
    jr       $t7

    //
    // Add a magic code here to help the VM recognize the thunk.
    //
    break   0x4EBC

0:  .quad   0   // EBC_ENTRYPOINT_SIGNATURE
    .quad   0   // EBC_LL_EBC_ENTRYPOINT_SIGNATURE
