//! By convention, root.zig is the root source file when making a package.
pub const parser = @import("parser.zig");
pub const Parsed = @import("Parsed.zig");

pub const parse = parser.parse;

test {
    _ = parser;
}
