const std = @import("std");

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;
const buitinConsoleCommands: [3][]const u8 = .{ "type", "exit", "echo" };

pub fn main() !void {
    var stdinBuffer: [4096]u8 = undefined; // sets a array of 4096 u8s as a buffer
    var stdinReader = std.fs.File.stdin().readerStreaming(&stdinBuffer); //Reads from buffer into reader
    const stdin = &stdinReader.interface; // pointer to interface in reader struct
    // takes user input from keyboard

    var allocatorBuffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&allocatorBuffer);
    const allocator = fba.allocator();
    while (true) {
        try stdout.print("$ ", .{});
        const commandLine = try stdin.takeDelimiter('\n'); // takes user input
        // with new line as delimiter
        // this if statement checks char by char if they are the same, so first argument has to be
        // u8 not []u8
        if (std.mem.eql(u8, commandLine.?, "exit")) break;
        try ParseConsoleCommand(allocator, commandLine.?);
    }
}

pub fn ParseConsoleCommand(allocator: std.mem.Allocator, command: []const u8) !void {
    const consoleCommand = try allocator.alloc(u8, 140);
    var index: usize = 0;
    var commandText: []const u8 = undefined;
    for (command) |char| {
        if (char != ' ') {
            consoleCommand[index] = char;
            index += 1;
        } else {
            consoleCommand[index] = 0;
            break;
        }
    }
    if (command.len > index + 1) commandText = command[index + 1 ..];
    if (!isType(consoleCommand[0..index])) {
        try stdout.print("{s}: not found\n", .{consoleCommand[0..index]});
        return;
    }
    if (std.mem.eql(u8, consoleCommand[0..index], "echo")) {
        try stdout.print("{s}\n", .{commandText});
        return;
    } else if (std.mem.eql(u8, consoleCommand[0..index], "type")) {
        try TypeCommand(commandText);
    } else {
        try stdout.print("{s}: not found\n", .{commandText});
    }
    allocator.free(consoleCommand);
}

pub fn TypeCommand(commandText: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var EnvMap = try std.process.getEnvMap(allocator); // This gives me a map of all enviornment variables
    const evnPath = EnvMap.get("PATH") orelse return error.OptionalValueIsNull; // gets the path variables
    var paths = std.mem.splitScalar(u8, evnPath, ':'); // separets all paths
    if (isType(commandText)) {
        try stdout.print("{s} is a shell builtin\n", .{commandText});
        return;
    } else {
        while (paths.next()) |path| {
            const fullPath = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, commandText }); // joins both strings with a / in the middle
            defer allocator.free(fullPath);
            //const file = std.fs.openFileAbsolute(fullPath, .{}) catch continue;
            //_ = file;
            var cwd = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
                continue;
            }; // gets a handler of the dir and sets iterate to true if error movest to the next folder//path
            defer cwd.close();
            var walker = try cwd.walk(allocator); // walker is used to iterate over the elements isnide a folder
            defer walker.deinit();
            while (try walker.next()) |file| {
                if (std.mem.eql(u8, file.basename, commandText)) {
                    const dir = std.fs.openFileAbsolute(path, .{ .mode = .read_only }) catch {
                        continue;
                    };
                    _ = dir;
                    try stdout.print("{s} is {s}\n", .{ commandText, fullPath });
                    return;
                }
            }
        }
    }

    try stdout.print("{s} not found\n", .{commandText});
    return;
}

pub fn isType(command: []const u8) bool {
    for (buitinConsoleCommands) |builtinCommand| {
        if (std.mem.eql(u8, builtinCommand, command)) return true;
    }
    return false;
}
