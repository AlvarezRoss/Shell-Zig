const std = @import("std");

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;

pub fn main() !void {
    var stdinBuffer: [4096]u8 = undefined; // sets a array of 4096 u8s as a buffer
    var stdinReader = std.fs.File.stdin().readerStreaming(&stdinBuffer); //Reads from buffer into reader
    const stdin = &stdinReader.interface; // pointer to interface in reader struct
    // takes user input from keyboard

    while (true) {
        try stdout.print("$ ", .{});
        const command = try stdin.takeDelimiter('\n'); // takes user input
        // with new line as delimiter
        // this if statement checks char by char if they are the same, so first argument has to be
        // u8 not []u8
        if (std.mem.eql(u8, command.?, "exit")) break;
        try stdout.print("{s}: command not found\n", .{command.?});
    }
}
