const std = @import("std");

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;

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
    const consoleCommand = try allocator.alloc(u8, 100);
    var index: usize = 0;
    for (command) |char| {
        if (char != ' ') {
            consoleCommand[index] = char;
            index += 1;
        } else {
            consoleCommand[index] = 0;
            break;
        }
    }
    if (std.mem.eql(u8, consoleCommand[0..index], "echo")) {
        try stdout.print("{s}\n", .{command[index + 1 ..]});
        return;
    } else if (std.mem.eql(u8, consoleCommand[0..index], "type") and isType(command[index + 1 ..])) {
        try stdout.print("{s}: is a shell builtin\n", .{command[index + 1 ..]});
    } else {
        try stdout.print("{s}: command not found\n", .{command[index + 1 ..]});
    }
    allocator.free(consoleCommand);
}

pub fn isType(command: []const u8) bool {
    if (std.mem.eql(u8, command, "echo") or std.mem.eql(u8, command, "exit")) return true;

    return false;
}
