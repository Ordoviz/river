// This file is part of river, a dynamic tiling wayland compositor.
//
// Copyright 2020 Isaac Freund
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");

const c = @import("c.zig");
const log = @import("log.zig");
const util = @import("util.zig");

const Server = @import("Server.zig");

const usage: []const u8 =
    \\Usage: river [options]
    \\
    \\  -h            Print this help message and exit.
    \\  -c <command>  Run `sh -c <command>` on startup.
    \\  -l <level>    Set the log level to a value from 0 to 7.
    \\
;

pub fn main() anyerror!void {
    var startup_command: ?[]const u8 = null;
    {
        var it = std.process.args();
        // Skip our name
        _ = it.nextPosix();
        while (it.nextPosix()) |arg| {
            if (std.mem.eql(u8, arg, "-h")) {
                const stdout = std.io.getStdOut().outStream();
                try stdout.print(usage, .{});
                std.os.exit(0);
            } else if (std.mem.eql(u8, arg, "-c")) {
                if (it.nextPosix()) |command| {
                    startup_command = command;
                } else {
                    printErrorExit("Error: flag '-c' requires exactly one argument", .{});
                }
            } else if (std.mem.eql(u8, arg, "-l")) {
                if (it.nextPosix()) |level_str| {
                    const level = std.fmt.parseInt(u3, level_str, 10) catch
                        printErrorExit("Error: invalid log level '{}'", .{level_str});
                    log.level = @intToEnum(log.Level, level);
                } else {
                    printErrorExit("Error: flag '-l' requires exactly one argument", .{});
                }
            } else {
                const stderr = std.io.getStdErr().outStream();
                try stderr.print(usage, .{});
                std.os.exit(1);
            }
        }
    }

    c.wlr_log_init(.WLR_ERROR, null);

    log.info(.server, "initializing", .{});

    var server: Server = undefined;
    try server.init();
    defer server.deinit();

    try server.start();

    if (startup_command) |cmd| {
        const child_args = [_][]const u8{ "/bin/sh", "-c", cmd };
        const child = try std.ChildProcess.init(&child_args, util.gpa);
        defer child.deinit();
        try std.ChildProcess.spawn(child);
    }

    log.info(.server, "running...", .{});

    server.run();

    log.info(.server, "shutting down", .{});
}

fn printErrorExit(comptime format: []const u8, args: var) noreturn {
    const stderr = std.io.getStdErr().outStream();
    stderr.print(format ++ "\n", args) catch std.os.exit(1);
    std.os.exit(1);
}
