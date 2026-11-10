const std = @import("std");
const Parsed = @import("Parsed.zig");

pub const ParseError = error{
    InvalidTzOffsetFormat,
    InvalidTzOffsetMinute,
    TzOffsetOverflow,
};

/// Parses offsets such as "8", "08:00", and "-0:30" into a `Parsed`.
pub fn parse(input: []const u8) ParseError!Parsed {
    if (input.len == 0) return ParseError.InvalidTzOffsetFormat;

    var negative = false;
    var start: usize = 0;
    if (input[0] == '+' or input[0] == '-') {
        negative = input[0] == '-';
        start = 1;
    }
    if (start == input.len) return ParseError.InvalidTzOffsetFormat;

    const body = input[start..];
    const colon = std.mem.indexOfScalar(u8, body, ':');

    var hours_text = body;
    var minutes_text: ?[]const u8 = null;
    if (colon) |index| {
        hours_text = body[0..index];
        minutes_text = body[index + 1 ..];
        if (std.mem.indexOfScalar(u8, minutes_text.?, ':') != null) {
            return ParseError.InvalidTzOffsetFormat;
        }
    }

    if (!isDigits(hours_text)) return ParseError.InvalidTzOffsetFormat;
    const hours = try parseUnsigned(hours_text);

    var minutes: u64 = 0;
    if (minutes_text) |text| {
        if (!isDigits(text)) return ParseError.InvalidTzOffsetFormat;
        for (text) |digit| {
            minutes = minutes * 10 + (digit - '0');
            if (minutes > 59) return ParseError.InvalidTzOffsetMinute;
        }
    }

    const limit: u64 = if (negative)
        @as(u64, std.math.maxInt(i32)) + 1
    else
        std.math.maxInt(i32);

    if (hours > limit / 60) return ParseError.TzOffsetOverflow;
    const hour_minutes = hours * 60;
    if (minutes > limit - hour_minutes) return ParseError.TzOffsetOverflow;
    const total_minutes = hour_minutes + minutes;

    var offset_minutes: i32 = undefined;
    if (!negative) {
        offset_minutes = @intCast(total_minutes);
    } else if (total_minutes == @as(u64, std.math.maxInt(i32)) + 1) {
        offset_minutes = std.math.minInt(i32);
    } else {
        offset_minutes = -@as(i32, @intCast(total_minutes));
    }

    return .{ .offset_minutes = offset_minutes };
}

fn isDigits(text: []const u8) bool {
    if (text.len == 0) return false;
    for (text) |c| {
        if (c < '0' or c > '9') return false;
    }
    return true;
}

fn parseUnsigned(text: []const u8) ParseError!u64 {
    var value: u64 = 0;
    for (text) |c| {
        const digit: u64 = c - '0';
        if (value > (std.math.maxInt(u64) - digit) / 10) {
            return ParseError.TzOffsetOverflow;
        }
        value = value * 10 + digit;
    }
    return value;
}

test "parses signed hour and minute offsets" {
    try std.testing.expectEqual(@as(i32, 480), (try parse("08:00")).offset_minutes);
    try std.testing.expectEqual(@as(i32, 480), (try parse("+8:0")).offset_minutes);
    try std.testing.expectEqual(@as(i32, 480), (try parse("8")).offset_minutes);
    try std.testing.expectEqual(@as(i32, -120), (try parse("-02:00")).offset_minutes);
    try std.testing.expectEqual(@as(i32, -30), (try parse("-0:30")).offset_minutes);
    try std.testing.expectEqual(@as(i32, 345), (try parse("+5:45")).offset_minutes);
}

test "rejects malformed or out-of-range offsets" {
    try std.testing.expectError(ParseError.InvalidTzOffsetFormat, parse(""));
    try std.testing.expectError(ParseError.InvalidTzOffsetFormat, parse("8:"));
    try std.testing.expectError(ParseError.InvalidTzOffsetFormat, parse("1:2:3"));
    try std.testing.expectError(ParseError.InvalidTzOffsetFormat, parse(" 8:00"));
    try std.testing.expectError(ParseError.InvalidTzOffsetMinute, parse("8:60"));
    try std.testing.expectError(ParseError.TzOffsetOverflow, parse("999999999999999999999"));
}
