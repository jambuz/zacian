.global create_file
.section .text

create_file:
    mov x0, xzr
    adr x1, path_name
    mov x2, #0x40
    mov x3, #0666
    mov x8, #56
    svc #0 

    // close(int fd)
    // (x0 already contains fd from open)
    mov x8, #57           // close syscall
    svc #0

    // Exit
    mov x0, #0            // status = 0
    mov x8, #93           // exit syscall
    svc #0

path_name:
    .asciz "/data/local/tmp/hello.txt"

