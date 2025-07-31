.section .text

write_file:
        # ic      iallu       // Invalidate all instruction cache to PoU
        # dsb     nsh         // Ensure completion of invalidation
        # isb                 // Synchronize pipeline
        mov x0, #0
        mov x8, #93 // exit // 94 = exit_group
        svc #0 
