const std = @import("std");

const MapParser = @import("lmap").MapParser;

const Injector = @import("injector.zig");

pub fn main() !void {
    var scratch_buf: [4 * 1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&scratch_buf);
    const allocator = fba.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    // TODO: add flags module for arg parsing
    if (args.next()) |pid| {
        const zygote_pid = try std.fmt.parseInt(std.os.linux.pid_t, pid, 10);

        var p = try MapParser.init(allocator, zygote_pid, null);
        defer p.deinit();

        const libc_mod = try p.getModuleMap("libc.so");
        std.log.debug("libc_base: {?x} at {?s}", .{ libc_mod.start, libc_mod.path });

        std.log.debug("Starting to trace Zygote ({d})...", .{zygote_pid});
        try Injector.inject(allocator, zygote_pid);
    } else return error.NoPidProvided;
}

test "a" {
    var scratch_buf: [4 * 1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&scratch_buf);
    const allocator = fba.allocator();

    const p = try MapParser.init(allocator, null, null);
    defer p.deinit();
}
