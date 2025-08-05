.section .text

trampoline:
    adr x0, bin_ls 

    stp x0, xzr, [sp, #-16]! // create and store custom argv on the stack
    mov x1, sp 
    mov x2, xzr 

    mov x8, #221 // execve syscall number
    svc #0 
    ret

bin_ls:
    .ascii "/bin/ls\0" // use .ascii instead of .asciz for clarity
