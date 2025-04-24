const std = @import("std");
const testing = std.testing;

const EnumIndexer = std.enums.EnumIndexer;
const EnumFieldStruct = std.enums.EnumFieldStruct;

const Flags = enum(u32) {
    Read = 0x1,
    Write = 0x2,
    Exec = 0x4,
};

pub fn PackedEnumSet(comptime E: type) type {
    return packed struct {
        const Self = @This();
        pub const Indexer = EnumIndexer(E);
        pub const Key = Indexer.Key;
        const BitSet = std.StaticBitSet(Indexer.count);
        pub const len = Indexer.count;

        bits: BitSet = BitSet.initEmpty(),

        pub fn init(init_values: EnumFieldStruct(E, bool, false)) Self {
            @setEvalBranchQuota(2 * @typeInfo(E).@"enum".fields.len);
            var result: Self = .{};
            if (@typeInfo(E).@"enum".is_exhaustive) {
                inline for (0..Self.len) |i| {
                    const key = comptime Indexer.keyForIndex(i);
                    const tag = @tagName(key);
                    if (@field(init_values, tag)) {
                        result.bits.set(i);
                    }
                }
            } else {
                inline for (std.meta.fields(E)) |field| {
                    const key = @field(E, field.name);
                    if (@field(init_values, field.name)) {
                        const i = comptime Indexer.indexOf(key);
                        result.bits.set(i);
                    }
                }
            }
            return result;
        }

        pub fn initEmpty() Self {
            return .{ .bits = BitSet.initEmpty() };
        }

        pub fn initFull() Self {
            return .{ .bits = BitSet.initFull() };
        }

        pub fn initMany(keys: []const Key) Self {
            var set = initEmpty();
            for (keys) |key| set.insert(key);
            return set;
        }

        pub fn initOne(key: Key) Self {
            return initMany(&[_]Key{key});
        }

        pub fn count(self: Self) usize {
            return self.bits.count();
        }

        pub fn contains(self: Self, key: Key) bool {
            return self.bits.isSet(key);
        }

        pub fn insert(self: *Self, key: Key) void {
            self.bits.set(Indexer.indexOf(key));
        }

        pub fn remove(self: *Self, key: Key) void {
            self.bits.unset(Indexer.indexOf(key));
        }

        pub fn setPresent(self: *Self, key: Key, present: bool) void {
            self.bits.setValue(Indexer.indexOf(key), present);
        }

        pub fn toggle(self: *Self, key: Key) void {
            self.bits.toggle(Indexer.indexOf(key));
        }

        pub fn toggleSet(self: *Self, other: Self) void {
            self.bits.toggleSet(other.bits);
        }

        pub fn toggleAll(self: *Self, other: Self) void {
            self.bits.toggleSet(other.bits);
        }

        pub fn setUnion(self: *Self, other: Self) void {
            self.bits.setUnion(other.bits);
        }

        pub fn setIntersection(self: *Self, other: Self) void {
            self.bits.setIntersection(other.bits);
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.bits.eql(other.bits);
        }

        pub fn subsetOf(self: Self, other: Self) bool {
            return self.bits.subsetOf(other.bits);
        }

        pub fn supersetOf(self: Self, other: Self) bool {
            return self.bits.supersetOf(other.bits);
        }

        pub fn complement(self: Self) Self {
            return .{ .bits = self.bits.complement() };
        }

        pub fn unionWith(self: Self, other: Self) Self {
            return .{ .bits = self.bits.unionWith(other.bits) };
        }

        pub fn intersectWith(self: Self, other: Self) Self {
            return .{ .bits = self.bits.intersectWith(other.bits) };
        }

        pub fn xorWith(self: Self, other: Self) Self {
            return .{ .bits = self.bits.xorWith(other.bits) };
        }

        pub fn differenceWith(self: Self, other: Self) Self {
            return .{ .bits = self.bits.differenceWith(other.bits) };
        }

        pub fn iterator(self: *const Self) Iterator {
            return .{ .inner = self.bits.iterator() };
        }

        pub const Iterator = struct {
            inner: BitSet.Iterator(.{}),

            pub fn next(self: *Iterator) ?Key {
                return if (self.inner.next()) |index|
                    Indexer.keyForIndex(index)
                else
                    null;
            }
        };
    };
}

test "PackedEnumSet Fns" {
    const Suit = enum { spades, hearts, clubs, diamonds };

    const empty = PackedEnumSet(Suit).initEmpty();
    const full = PackedEnumSet(Suit).initFull();
    const black = PackedEnumSet(Suit).initMany(&[_]Suit{ .spades, .clubs });
    const red = PackedEnumSet(Suit).initMany(&[_]Suit{ .hearts, .diamonds });

    try testing.expect(empty.eql(empty));
    try testing.expect(full.eql(full));
    try testing.expect(!empty.eql(full));
    try testing.expect(!full.eql(empty));
    try testing.expect(!empty.eql(black));
    try testing.expect(!full.eql(red));
    try testing.expect(!red.eql(empty));
    try testing.expect(!black.eql(full));

    try testing.expect(empty.subsetOf(empty));
    try testing.expect(empty.subsetOf(full));
    try testing.expect(full.subsetOf(full));
    try testing.expect(!black.subsetOf(red));
    try testing.expect(!red.subsetOf(black));

    try testing.expect(full.supersetOf(full));
    try testing.expect(full.supersetOf(empty));
    try testing.expect(empty.supersetOf(empty));
    try testing.expect(!black.supersetOf(red));
    try testing.expect(!red.supersetOf(black));

    try testing.expect(empty.complement().eql(full));
    try testing.expect(full.complement().eql(empty));
    try testing.expect(black.complement().eql(red));
    try testing.expect(red.complement().eql(black));

    try testing.expect(empty.unionWith(empty).eql(empty));
    try testing.expect(empty.unionWith(full).eql(full));
    try testing.expect(full.unionWith(full).eql(full));
    try testing.expect(full.unionWith(empty).eql(full));
    try testing.expect(black.unionWith(red).eql(full));
    try testing.expect(red.unionWith(black).eql(full));

    try testing.expect(empty.intersectWith(empty).eql(empty));
    try testing.expect(empty.intersectWith(full).eql(empty));
    try testing.expect(full.intersectWith(full).eql(full));
    try testing.expect(full.intersectWith(empty).eql(empty));
    try testing.expect(black.intersectWith(red).eql(empty));
    try testing.expect(red.intersectWith(black).eql(empty));

    try testing.expect(empty.xorWith(empty).eql(empty));
    try testing.expect(empty.xorWith(full).eql(full));
    try testing.expect(full.xorWith(full).eql(empty));
    try testing.expect(full.xorWith(empty).eql(full));
    try testing.expect(black.xorWith(red).eql(full));
    try testing.expect(red.xorWith(black).eql(full));

    try testing.expect(empty.differenceWith(empty).eql(empty));
    try testing.expect(empty.differenceWith(full).eql(empty));
    try testing.expect(full.differenceWith(full).eql(empty));
    try testing.expect(full.differenceWith(empty).eql(full));
    try testing.expect(full.differenceWith(red).eql(black));
    try testing.expect(full.differenceWith(black).eql(red));
}

test "PackedEnumSet empty" {
    const E = enum {};
    const empty = PackedEnumSet(E).initEmpty();
    const full = PackedEnumSet(E).initFull();

    try std.testing.expect(empty.eql(full));
    try std.testing.expect(empty.complement().eql(full));
    try std.testing.expect(empty.complement().eql(full.complement()));
    try std.testing.expect(empty.eql(full.complement()));
}

// All zig EnumSet tests
// test "PackedEnumSet const iterator" {
//     const Direction = enum { up, down, left, right };
//     const diag_move = init: {
//         var move = PackedEnumSet(Direction).initEmpty();
//         move.insert(.right);
//         move.insert(.up);
//         break :init move;
//     };
//
//     var result = PackedEnumSet(Direction).initEmpty();
//     var it = diag_move.iterator();
//     while (it.next()) |dir| {
//         result.insert(dir);
//     }
//
//     try testing.expect(result.eql(diag_move));
// }

// test "PackedEnumSet non-exhaustive" {
//     const BitIndices = enum(u4) {
//         a = 0,
//         b = 1,
//         c = 4,
//         _,
//     };
//     const BitField = PackedEnumSet(BitIndices);
//
//     var flags = BitField.init(.{ .a = true, .b = true });
//     flags.insert(.c);
//     flags.remove(.a);
//     try testing.expect(!flags.contains(.a));
//     try testing.expect(flags.contains(.b));
//     try testing.expect(flags.contains(.c));
// }
