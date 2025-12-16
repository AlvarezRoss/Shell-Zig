const std = @import("std");

var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
const stdout = &stdout_writer.interface;
const buitinConsoleCommands: [5][]const u8 = .{ "type", "exit", "echo", "pwd", "cd" };
const Errors = error{NotAccesableExe};
const commands = enum { type, exit, echo, pwd, cd };

pub fn main() !void {
    var stdinBuffer: [4096]u8 = undefined; // sets a array of 4096 u8s as a buffer
    var stdinReader = std.fs.File.stdin().readerStreaming(&stdinBuffer); //Reads from buffer into reader
    const stdin = &stdinReader.interface; // pointer to interface in reader struct
    // takes user input from keyboard

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

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
    defer allocator.free(consoleCommand);
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
        const exePath: []const u8 = CheckExe(allocator, consoleCommand[0..index]) catch {
            try stdout.print("{s}: not found\n", .{consoleCommand[0..index]});
            return;
        };
        _ = exePath;
        ExecuteExe(allocator, command) catch {
            return;
        };
        return;
    }
    if (std.mem.eql(u8, consoleCommand[0..index], "echo")) {
        try stdout.print("{s}\n", .{commandText});
        return;
    } else if (std.mem.eql(u8, consoleCommand[0..index], "type")) {
        try TypeCommand(commandText);
    } else if (std.mem.eql(u8, consoleCommand[0..index], "pwd")) {
        const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
        defer allocator.free(cwd);
        try stdout.print("{s}\n", .{cwd});
        return;
    } else if (std.mem.eql(u8, consoleCommand[0..index], "cd")) {
        std.posix.chdir(commandText) catch {
            try stdout.print("{s}: {s}: No such file or directory\n", .{ consoleCommand[0..index], commandText });
        };
        return;
    } else {
        try stdout.print("{s}: not found\n", .{commandText});
    }
}

pub fn TypeCommand(commandText: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    if (isType(commandText)) {
        try stdout.print("{s} is a shell builtin\n", .{commandText});
        arena.deinit();
        return;
    } else {
        const fullExePath = CheckExe(allocator, commandText) catch {
            try stdout.print("{s} not found\n", .{commandText});
            arena.deinit();
            return;
        };

        try stdout.print("{s} is {s}\n", .{ commandText, fullExePath });
        arena.deinit();
    }
}

pub fn isType(command: []const u8) bool {
    for (buitinConsoleCommands) |builtinCommand| {
        if (std.mem.eql(u8, builtinCommand, command)) return true;
    }

    return false;
}

pub fn CheckExe(allocator: std.mem.Allocator, command: []const u8) ![]const u8 {
    var envMap = try std.process.getEnvMap(allocator); // Gets Enviornment variables map
    const envPaths = envMap.get("PATH") orelse return error.OptionalValueNull; // gets the PATH variable
    var paths = std.mem.splitScalar(u8, envPaths, ':'); // Iterator over the paths in the PATH variable
    while (paths.next()) |path| {
        const fullPath: []const u8 = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, command }); // concats full path
        const access = std.posix.access(fullPath, std.posix.X_OK) catch { // tries to acces continues if error
            continue;
        };
        _ = access;
        return fullPath;
    }
    return Errors.NotAccesableExe;
}

pub fn ExecuteExe(allocator: std.mem.Allocator, args: []const u8) !void {
    var argv = std.mem.splitScalar(u8, args, ' ');
    var argList = try std.ArrayListUnmanaged([]const u8).initCapacity(allocator, 32);
    defer argList.deinit(allocator);
    while (argv.next()) |arg| {
        try argList.append(allocator, arg);
    }

    var newProgram = std.process.Child.init(argList.items, allocator);
    newProgram.stdout = std.fs.File.stdout();
    newProgram.stdin = std.fs.File.stdin();
    newProgram.stderr = std.fs.File.stderr();
    _ = try newProgram.spawnAndWait();

    return;
}

pub fn ChangeDirectory(path: []const u8, allocator: std.mem.Allocator) !void {
    const cwd: []const u8 = try std.fs.cwd().realpathAlloc(allocator, "."); // Gets current working directory
    defer allocator.free(cwd);

    const pathSplit = std.mem.splitScalar(u8, path, '/');
    // These two variables will be used in the case of ../ to calculate how many leves we have to go up the tree
    var levels: i32 = 0;
    const numLeves: i32 = pathSplit.rest().len;
    // THis will be the diference betweeen numLevels and levels
    var levesLeftInTree: i32 = 0;

    while (pathSplit.next()) |pathSection| {
        if (std.mem.eql(u8, pathSection, "..")) {
            levels += 1;
            continue;
        }

        if (std.mem.eql(u8, pathSection, ".")) {
            const newPath: []const u8 = try std.mem.concat(allocator, u8, pathSection, cwd[1..]);
            defer allocator.free(newPath);
            std.posix.chdir(newPath);
            return;
        }
        if (levels != 0 and !std.mem.eql(u8, pathSection, "..")) {
            break;
        } else {
            try std.posix.chdir(path);
            return;
        }
    }
    levesLeftInTree = numLeves - levels;
    if (levels >= numLeves) {
        const root: []const u8 = pathSplit.first();
        try std.posix.chdir(root);
        return;
    } else {
        var newPath: []const u8 = undefined;
        while (pathSplit.next()) |pth| {
            if (pathSplit.index >= levesLeftInTree) {
                break;
            } else {
                newPath = try std.fmt.allocPrint(allocator, "/{s}", pth); //This concats a new getion of the path with a / before it to the form the full final path
            }
        }
        try std.posix.chdir(newPath);
        allocator.free(newPath);
        return;
    }

    return;
}
