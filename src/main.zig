const std = @import("std");

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;

pub fn main() !void {
    try stdout.print("$ ", .{});
    var stdinBuffer: [4096]u8 = undefined; // sets a array of 4096 u8s as a buffer
    var stdinReader = std.fs.File.stdin().readerStreaming(&stdinBuffer); //Reads from buffer into reader
    const stdin = &stdinReader.interface; // pointer to interface in reader struct

    const command = stdin.takeDelimiter('\n'); // new line as delimiter

    try stdout.print("{s}: command not found", .{command.?});
}
