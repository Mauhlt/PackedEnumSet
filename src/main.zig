const std = @import("std");
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
            return self.bits.isSet(Indexer);
        }
    };
}

