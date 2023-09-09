const std = @import("std");

const Allocator = std.mem.Allocator;
const JSON = std.json;
const stdout = std.io.getStdOut();

const string = []const u8;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

fn println(str: string) !void {
    try stdout.writer().writeAll(str);
}

fn search(str: string, output: *string) !void {
    if (str.len == 0) return error.MissingQuery;

    var results = std.ArrayList(string).init(allocator);
    defer results.deinit();

    // Run npm search
    const npm_search = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{ "npm", "search", str, "--no-description", "-p" },
    });

    if (npm_search.stdout.len == 0) return error.NoResults;

    // Manually do what awk '{print $1}' would do since I couldn't pipe the results...
    var splits = std.mem.split(u8, npm_search.stdout, "\n");
    while (splits.next()) |line| {
        var split_line = std.mem.split(u8, line, "\t");
        try results.append(split_line.next().?);
    }

    output.* = try std.mem.join(allocator, " ", results.items);
}

fn remove(_: string, output: *string) !void {
    // Get package.json in cwd and parse it
    const package_json = try std.fs.cwd().openFile("package.json", .{});
    const source = try package_json.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    package_json.close();

    const root = try JSON.parseFromSliceLeaky(JSON.Value, allocator, source, .{});

    // Get packages
    const dependencies_object = root.object.get("dependencies") orelse return error.MissingDependencies;
    const devdependencies_object = root.object.get("devDependencies");
    var dependencies = std.ArrayList(string).init(allocator);

    // Iterate over dependencies
    var iter = dependencies_object.object.iterator();
    while (iter.next()) |dep| {
        try dependencies.append(dep.key_ptr.*);
    }

    // Iterate over devDependencies
    if (devdependencies_object != null) {
        iter = devdependencies_object.?.object.iterator();
        while (iter.next()) |dep| {
            try dependencies.append(dep.key_ptr.*);
        }
    }

    output.* = try std.mem.join(allocator, " ", dependencies.items);
}

fn run(_: string, output: *string) !void {
    // Get package.json in cwd and parse it
    const package_json = try std.fs.cwd().openFile("package.json", .{});
    const source = try package_json.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    package_json.close();

    const root = try JSON.parseFromSliceLeaky(JSON.Value, allocator, source, .{});

    // Get scripts
    const scripts_object = root.object.get("scripts") orelse return error.MissingDependencies;
    var scripts = std.ArrayList(string).init(allocator);

    // Iterate over scripts
    var iter = scripts_object.object.iterator();
    while (iter.next()) |dep| {
        try scripts.append(dep.key_ptr.*);
    }

    output.* = try std.mem.join(allocator, " ", scripts.items);
}

const commands = std.ComptimeStringMap(*const fn (string, *string) anyerror!void, .{
    .{ "add", search },
    .{ "remove", remove },
    .{ "run", run },
});

pub fn main() !void {
    const process_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, process_args);

    if (process_args.len == 1) return;

    var results: string = undefined;
    const arg = process_args[1];
    const query = if (process_args.len > 2) process_args[2] else "";

    if (commands.get(arg)) |command| {
        command(query, &results) catch return;
        try println(results);
    }
}
