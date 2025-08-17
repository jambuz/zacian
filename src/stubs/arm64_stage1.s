.section .text

stage1:
	adr x28, backup_stack
	sub x28, x28, #32
	stp x0, x1, [x28]
	stp x2, x3, [x28, #16]
	b 0x0

backup_stack:
	.space 256
