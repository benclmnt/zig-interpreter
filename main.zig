const std = @import("std");
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lexer.zig").Token;

const PROMPT = ">> ";

pub fn main() !void {
    try stdout.print("Welcome to Monkey REPL!\n", .{});
    try run();
}

fn run() !void {
    var buf: [128]u8 = undefined;
    try stdout.print(PROMPT, .{});
    while (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        var l = Lexer.init(line);
        while (true) {
            var tok = l.next();
            if (tok.tag == Token.Tag.eof) break;
            std.debug.print("{any}\n", .{tok});
        }
        try stdout.print(PROMPT, .{});
    }
}
