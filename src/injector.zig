const std = @import("std");

const ProcessMapParser = @import("lmap").ProcessMapParser;

const RemoteMemory = @import("remote/memory.zig").RemoteMemory;
const Registers = @import("remote/registers.zig");
const Stubs = @import("stubs.zig");

const PTRACE_O_TRACEFORK = 0x00000002;
const PTRACE_EVENT_FORK = 1;
const __WALL = 0x40000000;

/// Start ptracing, provide zygote pid
/// TODO: overhaul injection interface
pub inline fn inject(allocator: std.mem.Allocator, zygote_pid: std.posix.pid_t) !void {
    var wait_pid_result: std.posix.WaitPidResult = undefined;

    // 1. Attach to the target process using ptrace SEIZE and handle error with DETACH
    try std.posix.ptrace(std.os.linux.PTRACE.SEIZE, zygote_pid, 0, 0);
    errdefer std.posix.ptrace(std.os.linux.PTRACE.DETACH, zygote_pid, 0, 0) catch {};

    // 2. Interrupt the process to prepare for tracing
    try std.posix.ptrace(std.os.linux.PTRACE.INTERRUPT, zygote_pid, 0, 0);

    // 3. Wait for the target process to stop (due to ptrace interrupt)
    wait_pid_result = std.posix.waitpid(zygote_pid, 0);

    // 4. Set ptrace options to trace fork events
    try std.posix.ptrace(std.os.linux.PTRACE.SETOPTIONS, zygote_pid, 0, PTRACE_O_TRACEFORK);

    // 5. Resume the target process to allow execution
    try std.posix.ptrace(std.os.linux.PTRACE.CONT, zygote_pid, 0, 0);

    // 6. Wait for a fork event (child process creation)
    wait_pid_result = std.posix.waitpid(zygote_pid, __WALL);

    // 7. Check if a fork event has occurred
    if (wait_pid_result.status >> 8 == (std.os.linux.SIG.TRAP | (PTRACE_EVENT_FORK << 8))) {
        var child_pid: std.posix.pid_t = undefined;

        // 8. Retrieve the PID of the child process from ptrace event message
        try std.posix.ptrace(std.os.linux.PTRACE.GETEVENTMSG, zygote_pid, 0, @intFromPtr(&child_pid));

        // 9. Interrupt the child process for further tracing
        try std.posix.ptrace(std.os.linux.PTRACE.INTERRUPT, child_pid, 0, 0);
        std.log.debug("[*] Child PID: {}", .{child_pid});

        // 10. Wait for the child process to stop
        wait_pid_result = std.posix.waitpid(child_pid, 0);

        // 11. Initialize remote memory for the child process
        var remote_mem = try RemoteMemory.init(allocator, child_pid);
        defer remote_mem.deinit();

        // 12. Retrieve the current registers of the child process
        const regs = try Registers.getRegs(child_pid);
        std.log.debug("[*] Program counter (pc): {x}", .{regs.pc});

        // 13. Read 32 bytes of memory from the child's current program counter (pc)
        var initial_mem: [32]u8 = undefined;
        _ = try remote_mem.read(regs.pc, &initial_mem);
        std.log.debug("[*] 32 bytes at pc {x} = {x}", .{ regs.pc, std.fmt.fmtSliceHexLower(&initial_mem) });

        var parser = try ProcessMapParser.init(allocator, child_pid);
        defer parser.deinit();

        const libc_map_rx = blk: {
            for (parser.maps.items) |map| {
                if (std.mem.endsWith(u8, map.path, "libc.so") and map.perms.execute) {
                    break :blk map;
                }
            }
            return error.LibcNotFound;
        };

        // 14. write jmp
        const code_cave_addr = try remote_mem.getCodeCave(
            libc_map_rx.start,
            libc_map_rx.start + 1024 * 1024,
            Stubs.ARM64Trampoline.len,
        );
        std.log.debug("[*] code cave: {x}\n", .{code_cave_addr});

        // 15. write jmp
        try remote_mem.write(regs.pc, Stubs.ARM64Trampoline);

        // 16. write stub
        try remote_mem.write(code_cave_addr, Stubs.ARM64Trampoline);

        try std.posix.ptrace(std.os.linux.PTRACE.CONT, zygote_pid, 0, 0);
    } else {
        // If no fork event occurred, return an error
        return error.InjectionFailed;
    }
}
