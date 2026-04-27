# Goal:
- Create set that takes in enum keys and outputs d.s. that works with Vulkan extern vk fns (not extern fns)

# How?
1. Combine EnumSet, BitSet, PackedStruct
- packed struct = works with extern structs
- enumset = pass keys instead of values to get outcomes
- bitset = use these fns to modify internal bits which then get passed to extern vk fns 
2. Convert FlagBits to Masks
- take the tag type of flagbits to set internal maskint
- take log2 of flagbit value and set that bit position

## Getting Started:
Add  `PackedEnumSet` to your `build.zig.zon` .dependencies with:
```
zig fetch --save git+https://github.com/bphilip777/PackedEnumSet.git
```

and in your build fn inside `build.zig` add:
```zig
const packedenumset = b.dependency("PackedEnumSet", .{});
exe.root_module.addImport("PackedEnumSet", packedenumset.module("PackedEnumSet"));
```

Now in your code, import `packedenumset`
```zig
const PES = @import("PackedEnumSet");
```

Example Use Case:
```zig
const std = @import("std");
const PES = @import("PackedEnumSet");

pub fn main() void {
    // Example taken from: https://github.com/ziglang/zig/blob/master/lib/std/enums.zig
    const Direction = enum(u8) {up, down, left, right};
    const diag_move = init: {
        var move = PES(Direction).initEmpty();
        move.insert(.right);
        move.insert(.up);
        berak :init move;
    };

    var result = PES(Direction).initEmpty();
    var it = diag_move.iterator();
    while (it.next()) |dir| {
        result.insert(dir);
    }

    std.debug.print("Matches: {}!", .{result.eql(diag_move)});
}
```
