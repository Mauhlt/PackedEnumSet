const std = @import("std");
const print = std.debug.print;
const expectEqual = std.testing.expectEqual;
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
        pub const Key = E; // Indexer.Key; // do i want indexer.key or do i want the type?

        bits: tt = 0,

        pub const empty: Self = .{};
        pub const full: Self = .{ .bits = ~@as(tt, 0) };

        pub fn initMany(keys: []const Key) Self {
            var self: Self = .empty;
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
            // does not fail if key's value is 0
            return (self.bits & @intFromEnum(key)) == @intFromEnum(key);
        }

        pub fn contain(self: Self, keys: []const Key) bool {
            for (keys) |key| if (!self.contains(key)) return false;
            return true;
        }

        pub fn set(self: *Self, key: Key) void {
            self.bits |= @intFromEnum(key);
        }

        pub fn unset(self: *Self, key: Key) void {
            self.bits &= ~@intFromEnum(key);
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.bits == other.bits;
        }

        pub fn isSubsetOf(self: Self, other: Self) bool {
            return self.intersectsWith(other).eql(self);
        }

        pub fn isSupersetOf(self: Self, other: Self) bool {
            return other.isSubsetOf(self);
        }

        pub fn intersectsWith(self: Self, other: Self) Self {
            var result = self;
            result.setIntersection(other); // takes pointer
            return result;
        }

        pub fn setUnion(self: *Self, other: Self) void {
            self.bits |= other.bits;
        }

        pub fn setIntersection(self: *Self, other: Self) void {
            self.bits &= other.bits;
        }

        pub fn findLastSet(self: Self) ?usize {
            // finds lsb
            const bits = @ctz(self.bits);
            return if (bits == @typeInfo(@TypeOf(self.bits)).int.bits) null else bits;
        }

        pub fn findFirstSet(self: Self) ?usize {
            // finds msb
            const bits = @clz(self.bits);
            if (bits == @typeInfo(@TypeOf(self.bits)).int.bits) return null;
            return @typeInfo(@TypeOf(self.bits)).int.bits - bits - 1;
        }
    };
}

test "ExternEnumSet Fns" {
    const Suit = enum(u32) {
        unknown = 0, //                 00000000
        spades = @as(u32, 1) << 0, //   00000001
        hearts = @as(u32, 1) << 1, //   00000010
        clubs = @as(u32, 1) << 2, //    00000100
        diamonds = @as(u32, 1) << 3, // 00001000
    };

    const empty: ExternEnumSet(Suit) = .empty; // 00000000
    try expectEqual(empty.bits, 0);
    const full: ExternEnumSet(Suit) = .full; // 11111111
    try expectEqual(full.bits, std.math.maxInt(u32));
    const black: ExternEnumSet(Suit) = .initMany(&[_]Suit{ .spades, .clubs }); // 00000101
    try expectEqual(black.bits, 5);
    const red: ExternEnumSet(Suit) = .initMany(&[_]Suit{ .hearts, .diamonds }); // 00001010
    try expectEqual(red.bits, 10);

    for (
        [_]usize{ empty.count(), full.count(), black.count(), red.count() },
        [_]usize{ 0, 32, 2, 2 },
    ) |count, exp_count| {
        try expectEqual(exp_count, count);
    }

    const unknown: ExternEnumSet(Suit) = .init(.unknown);
    try expectEqual(empty.bits, unknown.bits);
    const has_unknown = unknown.contains(.unknown);
    try expectEqual(true, has_unknown);

    const has_spades_and_clubs_1 = black.contains(.spades) and black.contains(.clubs);
    try expectEqual(true, has_spades_and_clubs_1);
    const no_has_hearts_and_diamonds_1 = black.contains(.hearts) and black.contains(.diamonds);
    try expectEqual(false, no_has_hearts_and_diamonds_1);

    const has_hearts_and_diamonds_2 = red.contain(&.{ .hearts, .diamonds });
    try expectEqual(true, has_hearts_and_diamonds_2);
    const no_has_spades_clubs_2 = red.contain(&.{ .spades, .clubs });
    try expectEqual(false, no_has_spades_clubs_2);

    var full_set: ExternEnumSet(Suit) = .empty;
    full_set.set(.spades);
    try expectEqual(1, full_set.bits);
    full_set.set(.hearts);
    try expectEqual(3, full_set.bits);
    full_set.set(.clubs);
    try expectEqual(7, full_set.bits);
    full_set.set(.diamonds);
    try expectEqual(15, full_set.bits);

    var empty_set = full_set;
    empty_set.unset(.spades);
    try expectEqual(14, empty_set.bits);
    empty_set.unset(.hearts);
    try expectEqual(12, empty_set.bits);
    empty_set.unset(.clubs);
    try expectEqual(8, empty_set.bits);
    empty_set.unset(.diamonds);
    try expectEqual(0, empty_set.bits);

    const rando_set1: ExternEnumSet(Suit) = .initMany(&.{ .spades, .diamonds });
    const rando_set2: ExternEnumSet(Suit) = .initMany(&.{ .diamonds, .spades });
    const rando_set3: ExternEnumSet(Suit) = .initMany(&.{ .spades, .hearts });
    const is_eql = rando_set1.eql(rando_set2);
    try expectEqual(true, is_eql);
    const is_not_eql = rando_set1.eql(rando_set3);
    try expectEqual(false, is_not_eql);

    const subset: ExternEnumSet(Suit) = .initMany(&.{ .spades, .hearts });
    const superset1: ExternEnumSet(Suit) = .initMany(&.{ .diamonds, .spades, .hearts });
    const superset2: ExternEnumSet(Suit) = .initMany(&.{ .spades, .diamonds, .clubs });
    const is_subset = subset.isSubsetOf(superset1);
    try expectEqual(true, is_subset);
    const is_superset = superset1.isSupersetOf(subset);
    try expectEqual(true, is_superset);
    const not_subset = subset.isSubsetOf(superset2);
    try expectEqual(false, not_subset);
    const not_superset = superset2.isSupersetOf(subset);
    try expectEqual(false, not_superset);

    const first_null = empty.findFirstSet();
    try expectEqual(null, first_null);
    const last_null = empty.findFirstSet();
    try expectEqual(null, last_null);
    const first_black = black.findLastSet().?;
    try expectEqual(0, first_black);
    const first_red = red.findLastSet().?;
    try expectEqual(1, first_red);
    const last_black = black.findFirstSet().?;
    try expectEqual(2, last_black);
    const last_red = red.findFirstSet().?;
    try expectEqual(3, last_red);
}

