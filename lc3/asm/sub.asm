.ORIG x3000
LD R1, a

JSR SUB_TWOS_COMP
ADD R0, R1, #0

HALT
a .FILL xCCCC

SUB_TWOS_COMP
ST R7, BACKUP_R7
	NOT R1, R1
	ADD R1, R1, #1
LD R7, BACKUP_R7
JMP R7 ;RET
BACKUP_R7 .BLKW #1

.END