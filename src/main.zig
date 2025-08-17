const std = @import("std");

const Injector = @import("injector.zig");

// https://excalidraw.com/#json=RAiLMbQiFaBtuJ0S-cHi-,T6KGi32Rvgf0SSrKpFdJlA
pub fn main() !void {
    var scratch_buf: [4 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&scratch_buf);
    const allocator = fba.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    // TODO: add flags module for arg parsing
    if (args.next()) |pid_str| {
        const zygote_pid = try std.fmt.parseInt(std.os.linux.pid_t, pid_str, 10);
        std.log.debug("[*] Starting to trace Zygote ({d})...", .{zygote_pid});
        try Injector.inject(allocator, zygote_pid);
    } else return error.NoPidProvided;
}
