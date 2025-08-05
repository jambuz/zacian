.section .text

branch_to_addr:
        mov x0, #0xaaaa // first 2 bytes
        movk x0, #0xbbbb, lsl #16
        movk x0, #0xcc, lsl #32
        blr x0
