const std = @import("std");

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const Tag = enum {
        illegal,
        eof,
        identifier,
        int_literal,
        // operators
        plus,
        minus,
        asterisk,
        slash,
        bang,
        angle_bracket_left,
        angle_bracket_right,
        equal,
        equal_equal,
        bang_equal,
        // delimiters
        comma,
        semicolon,
        l_paren,
        r_paren,
        l_brace,
        r_brace,
        keyword_fn,
        keyword_let,
        keyword_true,
        keyword_false,
        keyword_if,
        keyword_else,
        keyword_return,
    };

    pub const Keywords = std.ComptimeStringMap(Tag, .{
        .{ "fn", .keyword_fn },
        .{ "let", .keyword_let },
        .{ "true", .keyword_true },
        .{ "false", .keyword_false },
        .{ "if", .keyword_if },
        .{ "else", .keyword_else },
        .{ "return", .keyword_return },
    });
};

pub const Lexer = struct {
    input: []const u8,
    pos: usize = 0,

    /// For debugging purposes
    pub fn dump(self: *Lexer, token: *const Token) void {
        std.debug.print("{s} \"{s}\"\n", .{ @tagName(token.tag), self.input[token.start..token.end] });
    }

    pub fn init(input: []const u8) Lexer {
        return Lexer{
            .input = input,
        };
    }

    const State = enum {
        start,
        plus,
        minus,
        asterisk,
        slash,
        bang,
        equal,
        angle_bracket_left,
        angle_bracket_right,
        identifier,
        int_literal,
    };

    pub fn next(self: *Lexer) Token {
        var state: State = .start;
        var result = Token{ .tag = .eof, .loc = .{ .start = self.pos, .end = undefined } };

        while (true) : (self.pos += 1) {
            if (self.pos >= self.input.len) {
                result.loc.end = self.pos;
                return result;
            }
            const c = self.input[self.pos];
            switch (state) {
                .start => switch (c) {
                    0 => break,
                    ' ', '\n', '\r', '\t' => result.loc.start = self.pos + 1,
                    '+' => state = .plus,
                    '-' => state = .minus,
                    '*' => state = .asterisk,
                    '/' => state = .slash,
                    '!' => state = .bang,
                    '<' => state = .angle_bracket_left,
                    '>' => state = .angle_bracket_right,
                    '=' => state = .equal,
                    '{' => {
                        result.tag = .l_brace;
                        self.pos += 1;
                        break;
                    },
                    '}' => {
                        result.tag = .r_brace;
                        self.pos += 1;
                        break;
                    },
                    '(' => {
                        result.tag = .l_paren;
                        self.pos += 1;
                        break;
                    },
                    ')' => {
                        result.tag = .r_paren;
                        self.pos += 1;
                        break;
                    },
                    ',' => {
                        result.tag = .comma;
                        self.pos += 1;
                        break;
                    },
                    ';' => {
                        result.tag = .semicolon;
                        self.pos += 1;
                        break;
                    },
                    'a'...'z', 'A'...'Z', '_' => {
                        state = .identifier;
                        result.tag = .identifier;
                    },
                    '0'...'9' => {
                        state = .int_literal;
                        result.tag = .int_literal;
                    },
                    else => {
                        result.tag = .illegal;
                        self.pos += 1;
                        break;
                    },
                },
                // NOTE: this break down is so that it's easily extensible
                // e.g. if we need to support '+=' in the future.
                .plus => {
                    result.tag = .plus;
                    break;
                },
                .minus => {
                    result.tag = .minus;
                    break;
                },
                .asterisk => {
                    result.tag = .asterisk;
                    break;
                },
                .slash => {
                    result.tag = .slash;
                    break;
                },
                .angle_bracket_left => {
                    result.tag = .angle_bracket_left;
                    break;
                },
                .angle_bracket_right => {
                    result.tag = .angle_bracket_right;
                    break;
                },
                .bang => switch (c) {
                    '=' => {
                        result.tag = .bang_equal;
                        self.pos += 1;
                        break;
                    },
                    else => {
                        result.tag = .bang;
                        break;
                    },
                },
                .equal => switch (c) {
                    '=' => {
                        result.tag = .equal_equal;
                        self.pos += 1;
                        break;
                    },
                    else => {
                        result.tag = .equal;
                        break;
                    },
                },
                .identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '_' => {},
                    else => {
                        var ident = self.input[result.loc.start..self.pos];
                        if (Token.Keywords.get(ident)) |tag| {
                            result.tag = tag;
                        }
                        break;
                    },
                },
                .int_literal => switch (c) {
                    '0'...'9' => {},
                    else => break,
                },
            }
        }

        result.loc.end = self.pos;
        return result;
    }
};

test "next token - complete program" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\
        \\let add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\let result = add(five, ten);
        \\!-/*5;
        \\5 < 10 > 5;
        \\
        \\if (5 < 10) {
        \\	return true;
        \\} else {
        \\	return false;
        \\}
        \\
        \\10 == 10;
        \\10 != 9;
        \\
    ;
    var l = Lexer.init(input);
    const expected = [_]Token.Tag{
        // let five = 5;
        .keyword_let,
        .identifier,
        .equal,
        .int_literal,
        .semicolon,
        // let ten = 10;
        .keyword_let,
        .identifier,
        .equal,
        .int_literal,
        .semicolon,
        //let add = fn(x, y) {
        .keyword_let,
        .identifier,
        .equal,
        .keyword_fn,
        .l_paren,
        .identifier,
        .comma,
        .identifier,
        .r_paren,
        .l_brace,
        // x + y;
        .identifier,
        .plus,
        .identifier,
        .semicolon,
        // };
        .r_brace,
        .semicolon,
        // let result = add(five, ten);
        .keyword_let,
        .identifier,
        .equal,
        .identifier,
        .l_paren,
        .identifier,
        .comma,
        .identifier,
        .r_paren,
        .semicolon,
        // !-/*5;
        .bang,
        .minus,
        .slash,
        .asterisk,
        .int_literal,
        .semicolon,
        // 5 < 10 > 5;
        .int_literal,
        .angle_bracket_left,
        .int_literal,
        .angle_bracket_right,
        .int_literal,
        .semicolon,
        // if (5 < 10) {
        .keyword_if,
        .l_paren,
        .int_literal,
        .angle_bracket_left,
        .int_literal,
        .r_paren,
        .l_brace,
        // return true;
        .keyword_return,
        .keyword_true,
        .semicolon,
        // } else {
        .r_brace,
        .keyword_else,
        .l_brace,
        // return false;
        .keyword_return,
        .keyword_false,
        .semicolon,
        // }
        .r_brace,
        // 10 == 10;
        .int_literal,
        .equal_equal,
        .int_literal,
        .semicolon,
        // 10 != 9;
        .int_literal,
        .bang_equal,
        .int_literal,
        .semicolon,
    };

    for (expected) |tag| {
        try std.testing.expectEqual(tag, l.next().tag);
    }
}
