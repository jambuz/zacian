const std = @import("std");
const builtin = @import("builtin");

// https://cs.android.com/android/platform/superproject/main/+/main:bionic/libc/kernel/uapi/asm-arm64/asm/ptrace.h;l=49?q=user_pt_regs
const user_pt_regs = switch (builtin.os.tag) {
    .linux => blk: {
        if (builtin.abi == .android) {
            break :blk struct {
                regs: [31]c_ulonglong,
                sp: c_ulonglong,
                pc: c_ulonglong,
                pstate: c_ulonglong,
            };
        } else {
            @compileError("Unsupported ABI");
        }
    },
    else => @compileError("Unsupported OS"),
};

const NT_PRSTATUS = 1;

pub fn getRegs(pid: std.posix.pid_t) !user_pt_regs {
    var regs: user_pt_regs = undefined;
    const io = std.posix.iovec_const{
        .base = @ptrCast(&regs),
        .len = @sizeOf(user_pt_regs),
    };
    try std.posix.ptrace(std.os.linux.PTRACE.GETREGSET, pid, NT_PRSTATUS, @intFromPtr(&io));
    return regs;
}

pub fn setRegs(pid: std.posix.pid_t, regs: user_pt_regs) !void {
    const io = std.posix.iovec_const{
        .base = @ptrCast(&regs),
        .len = @sizeOf(user_pt_regs),
    };
    try std.posix.ptrace(std.os.linux.PTRACE.SETREGSET, pid, NT_PRSTATUS, @intFromPtr(&io));
}
