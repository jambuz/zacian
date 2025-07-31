const std = @import("std");

const RemoteMemory = @import("remote/memory.zig").RemoteMemory;
const Registers = @import("remote/registers.zig");
const Stubs = @import("stubs.zig");

const PTRACE_O_TRACEFORK = 0x00000002;
const PTRACE_EVENT_FORK = 1;
const __WALL = 0x40000000;

/// Start ptracing, provide zygote pid
/// TODO: overhaul injection interface
pub inline fn inject(allocator: std.mem.Allocator, pid: std.posix.pid_t) !void {
    var wait_pid_result: std.posix.WaitPidResult = undefined;

    try std.posix.ptrace(std.os.linux.PTRACE.SEIZE, pid, 0, 0);
    try std.posix.ptrace(std.os.linux.PTRACE.INTERRUPT, pid, 0, 0);
    wait_pid_result = std.posix.waitpid(pid, 0);

    try std.posix.ptrace(std.os.linux.PTRACE.SETOPTIONS, pid, 0, PTRACE_O_TRACEFORK);
    try std.posix.ptrace(std.os.linux.PTRACE.CONT, pid, 0, 0);
    wait_pid_result = std.posix.waitpid(pid, __WALL);
    errdefer std.posix.ptrace(std.os.linux.PTRACE.DETACH, pid, 0, 0) catch {};

    if (wait_pid_result.status >> 8 == (std.os.linux.SIG.TRAP | (PTRACE_EVENT_FORK << 8))) {
        var new_pid: std.posix.pid_t = undefined;

        try std.posix.ptrace(std.os.linux.PTRACE.GETEVENTMSG, pid, 0, @intFromPtr(&new_pid));
        try std.posix.ptrace(std.os.linux.PTRACE.INTERRUPT, new_pid, 0, 0);
        std.log.debug("[*] Child PID: {}", .{new_pid});
        wait_pid_result = std.posix.waitpid(new_pid, 0);

        var remote_mem = try RemoteMemory.init(allocator, new_pid);
        defer remote_mem.deinit();

        const regs = try Registers.getRegs(new_pid);
        std.log.debug("pc: {x}", .{regs.pc});

        var initial_mem: [32]u8 = undefined;
        _ = try remote_mem.read(regs.pc, &initial_mem);
        std.log.debug("32 bytes at pc {x} = {x}", .{ regs.pc, std.fmt.fmtSliceHexLower(&initial_mem) });

        try remote_mem.write(regs.pc + 4, Stubs.ARM64Segfault);

        var new_mem: [64]u8 = undefined;
        _ = try remote_mem.read(regs.pc - 32, &new_mem);
        std.log.debug("+-64 bytes at pc {x} = {x}", .{ regs.pc, std.fmt.fmtSliceHexLower(&new_mem) });

        std.posix.nanosleep(5, 0);
        try std.posix.ptrace(std.os.linux.PTRACE.CONT, pid, 0, 0);
    } else return error.InjectionFailed;
}
