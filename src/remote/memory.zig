const std = @import("std");

pub const RemoteMemory = struct {
    allocator: std.mem.Allocator,
    proc_mem_file: std.fs.File,
    pid: ?std.posix.pid_t,

    pub fn init(allocator: std.mem.Allocator, pid: ?std.posix.pid_t) !@This() {
        const proc_mem_path = blk: {
            if (pid) |p| {
                break :blk try std.fmt.allocPrint(allocator, "/proc/{d}/mem", .{p});
            } else {
                break :blk "/proc/self/mem";
            }
        };
        errdefer allocator.free(proc_mem_path);

        const proc_mem_file = try std.fs.openFileAbsolute(proc_mem_path, .{ .mode = .read_write });

        return .{
            .allocator = allocator,
            .pid = pid,
            .proc_mem_file = proc_mem_file,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.proc_mem_file.close();
    }

    pub fn getCodeCave(self: @This(), search_start_addr: usize, cave_size: usize) !usize {}

    pub inline fn read(self: @This(), addr: usize, buf: []u8) !usize {
        try self.proc_mem_file.seekTo(addr);
        return self.proc_mem_file.read(buf);
    }

    pub inline fn write(self: @This(), addr: usize, data: []const u8) !void {
        try self.proc_mem_file.seekTo(addr);
        _ = try self.proc_mem_file.write(data);
    }

    pub fn readIov(self: @This(), addr: usize, buf: []u8) !usize {
        if (self.pid) |pid| {
            const local = &[_]std.posix.iovec{
                .{
                    .base = @ptrCast(buf.ptr),
                    .len = buf.len,
                },
            };

            const remote = &[_]std.posix.iovec_const{
                .{
                    .base = @ptrFromInt(addr),
                    .len = buf.len,
                },
            };
            return std.os.linux.process_vm_readv(pid, local, remote, 0);
        }
        return error.InvalidPid;
    }

    pub fn writeIov(self: @This(), addr: usize, data: []u8) !void {
        if (self.pid) |pid| {
            const local = &[_]std.posix.iovec{
                .{
                    .base = @ptrCast(&data.ptr),
                    .len = data.len,
                },
            };

            const remote = &[_]std.posix.iovec_const{
                .{
                    .base = @ptrFromInt(addr),
                    .len = data.len,
                },
            };
            if (std.os.linux.process_vm_writev(pid, local, remote, 0) == -1) {
                return error.WriteFailed;
            }
        }
        return error.InvalidPid;
    }
};
