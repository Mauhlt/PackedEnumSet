const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const EnumIndexer = std.enums.EnumIndexer;

pub fn PackedEnumSet(comptime E: type) type {
    switch (@typeInfo(E)) {
        .@"enum" => {
            switch (@typeInfo(@typeInfo(E).@"enum".tag_type)) {
                .int => |int| {
                    switch (int.signedness) {
                        .signed => @compileError("Fn only accepts enums w/ tag types of unsigned ints."),
                        .unsigned => {},
                    }
                },
                else => @compileError("Fn only accepts enums w/ tag types of unsigned ints."),
            }
        },
        else => @compileError("Fn only accepts enums w/ tag types of unsigned ints."),
    }
    const tt = @typeInfo(E).@"enum".tag_type;

    return packed struct {
        const Self = @This();
        pub const Indexer = EnumIndexer(E);
        pub const Key = Indexer.Key;

        bits: tt = 0,

        pub fn initEmpty() Self {
            return .{};
        }

        pub fn initFull() Self {
            return .{ .bits = ~@as(tt, 0) };
        }

        pub fn initMany(keys: []const Key) Self {
            var self = initEmpty();
            for (keys) |key| self.set(key);
            return self;
        }

        pub fn init(key: Key) Self {
            return initMany(&[_]Key{key});
        }

        pub fn count(self: Self) usize {
            return @popCount(self.bits);
        }

        pub fn contains(self: Self, key: Key) bool {
            return (self.bits & @intFromEnum(key)) != 0;
        }

        pub fn set(self: *Self, key: Key) void {
            self.bits |= @intFromEnum(key);
        }

        pub fn unset(self: *Self, key: Key) void {
            self.bits &= ~@intFromEnum(key);
        }

        pub fn eql(self: Self, other: Self) bool {
            self.bits == other.bits;
        }

        pub fn subsetOf(self: Self, other: Self) bool {
            return self.intersectWith(other).eql(self);
        }

        pub fn supersetOf(self: *const Self, other: *const Self) bool {
            return other.subsetOf(self);
        }

        pub fn intersectWith(self: Self, other: Self) Self {
            var result = self;
            result.setIntersection(other);
            return result;
        }

        pub fn setUnion(self: *Self, other: Self) void {
            self.bits |= other.bits;
        }

        pub fn setIntersection(self: *Self, other: Self) void {
            self.bits &= other.bits;
        }

        pub fn findFirstSet(self: Self) ?usize {
            return @ctz(self.bits);
        }

        pub fn findLastSet(self: Self) ?usize {
            return @clz(self.bits);
        }
    };
}

test "PackedEnumSet Fns" {
    const Suit = enum(u32) {
        spades = 0,
        hearts = 1,
        clubs = 2,
        diamonds = 4,
    };

    const empty = PackedEnumSet(Suit).initEmpty();
    const full = PackedEnumSet(Suit).initFull();
    const black = PackedEnumSet(Suit).initMany(&[_]Suit{ .spades, .clubs });
    const red = PackedEnumSet(Suit).initMany(&[_]Suit{ .hearts, .diamonds });

    try testing.expectEqual(empty.bits, 0);
    try testing.expectEqual(full.bits, std.math.maxInt(u32));
    try testing.expectEqual(black.bits, 2);
    try testing.expectEqual(red.bits, 5);
}
