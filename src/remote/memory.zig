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

    // TODO: reconsider utilizing std.mem.indexOf
    pub fn getCodeCave(self: @This(), search_start_addr: usize, search_end_addr: usize, comptime cave_size: usize) !usize {
        const buf_size = search_end_addr - search_start_addr;
        const buf = try self.allocator.alloc(u8, buf_size);
        defer self.allocator.free(buf);

        const read_len = try self.readIov(search_start_addr, buf);
        const match = try self.allocator.create([cave_size]u8);
        defer self.allocator.destroy(match);

        const offset = std.mem.indexOf(u8, buf[0..read_len], match) orelse return error.CaveNotFound;
        return search_start_addr + offset;

        // var consecutive_zeros: usize = 0;
        // for (buf[0..read_len], 0..) |byte, i| {
        //     if (byte == 0x00) {
        //         consecutive_zeros += 1;
        //         if (consecutive_zeros >= cave_size) {
        //             return search_start_addr + i - (cave_size - 1);
        //         }
        //     } else {
        //         consecutive_zeros = 0;
        //     }
        // }

        // return error.CaveNotFound;
    }

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

    pub fn deinit(self: *@This()) void {
        self.proc_mem_file.close();
    }
};
