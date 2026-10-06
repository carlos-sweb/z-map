const std = @import("std");
const testing = std.testing;
const ZMap = @import("zmap").ZMap;

test "set/get/has/delete basic behavior" {
    var map = ZMap(i32, []const u8).init(testing.allocator);
    defer map.deinit();

    try map.set(1, "one");
    try map.set(2, "two");

    try testing.expectEqualStrings("one", map.get(1).?);
    try testing.expect(map.has(2));
    try testing.expect(!map.has(3));
    try testing.expectEqual(@as(usize, 2), map.size());

    try testing.expect(map.delete(1));
    try testing.expect(!map.delete(1)); // already gone
    try testing.expectEqual(@as(usize, 1), map.size());
}

test "keys()/values() preserve insertion order" {
    var map = ZMap(i32, i32).init(testing.allocator);
    defer map.deinit();

    try map.set(30, 300);
    try map.set(10, 100);
    try map.set(20, 200);

    try testing.expectEqualSlices(i32, &[_]i32{ 30, 10, 20 }, map.keys());
    try testing.expectEqualSlices(i32, &[_]i32{ 300, 100, 200 }, map.values());
}

test "delete() then set() moves the key to the end" {
    var map = ZMap(i32, i32).init(testing.allocator);
    defer map.deinit();

    try map.set(1, 1);
    try map.set(2, 2);
    try map.set(3, 3);

    try testing.expect(map.delete(1));
    try map.set(1, 111); // re-added: goes to the end, not back to its old spot

    try testing.expectEqualSlices(i32, &[_]i32{ 2, 3, 1 }, map.keys());
    try testing.expectEqual(@as(i32, 111), map.get(1).?);
}

test "set() on an existing key updates value WITHOUT moving its position" {
    var map = ZMap(i32, i32).init(testing.allocator);
    defer map.deinit();

    try map.set(1, 1);
    try map.set(2, 2);
    try map.set(3, 3);

    try map.set(2, 222); // re-set existing key: same position, new value

    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 3 }, map.keys());
    try testing.expectEqual(@as(i32, 222), map.get(2).?);
}

test "SameValueZero: NaN key finds itself, +0/-0 are the same key" {
    var map = ZMap(f64, i32).init(testing.allocator);
    defer map.deinit();

    const nan = std.math.nan(f64);
    try map.set(nan, 1);
    try testing.expect(map.has(nan));
    try testing.expect(map.has(std.math.nan(f64))); // a *different* NaN bit pattern-equivalent value

    try map.set(0.0, 100);
    try testing.expectEqual(@as(i32, 100), map.get(-0.0).?);
}

test "entries() and forEach() see the same insertion order as keys()" {
    var map = ZMap(i32, i32).init(testing.allocator);
    defer map.deinit();

    try map.set(3, 30);
    try map.set(1, 10);
    try map.set(2, 20);

    const es = try map.entries(testing.allocator);
    defer testing.allocator.free(es);
    try testing.expectEqual(@as(i32, 3), es[0].key);
    try testing.expectEqual(@as(i32, 1), es[1].key);
    try testing.expectEqual(@as(i32, 2), es[2].key);

    var visited: std.ArrayList(i32) = .empty;
    defer visited.deinit(testing.allocator);
    map.forEach(&visited, struct {
        fn callback(ctx: *std.ArrayList(i32), key: i32, value: i32) void {
            _ = value;
            ctx.append(testing.allocator, key) catch unreachable;
        }
    }.callback);
    try testing.expectEqualSlices(i32, &[_]i32{ 3, 1, 2 }, visited.items);
}

test "fromSlice builds a map in the given order" {
    const Entry = ZMap(i32, []const u8).Entry;
    var map = try ZMap(i32, []const u8).fromSlice(testing.allocator, &[_]Entry{
        .{ .key = 1, .value = "a" },
        .{ .key = 2, .value = "b" },
    });
    defer map.deinit();

    try testing.expectEqual(@as(usize, 2), map.size());
    try testing.expectEqualStrings("a", map.get(1).?);
}

test "ZMap with []const u8 keys compares by content, not pointer identity" {
    var map = ZMap([]const u8, i32).init(testing.allocator);
    defer map.deinit();

    try map.set("hello", 1);

    var buf: [5]u8 = .{ 'h', 'e', 'l', 'l', 'o' };
    try testing.expect(map.has(buf[0..]));
}

test "clear() empties the map" {
    var map = ZMap(i32, i32).init(testing.allocator);
    defer map.deinit();

    try map.set(1, 1);
    try map.set(2, 2);
    map.clear();

    try testing.expectEqual(@as(usize, 0), map.size());
    try testing.expect(!map.has(1));
}

test "fetchDelete() removes the key and returns the stored entry" {
    var map = ZMap(i32, []const u8).init(testing.allocator);
    defer map.deinit();

    try map.set(1, "one");
    try map.set(2, "two");
    try map.set(3, "three");

    const entry = map.fetchDelete(2).?;
    try testing.expectEqual(@as(i32, 2), entry.key);
    try testing.expectEqualStrings("two", entry.value);
    try testing.expect(!map.has(2));
    // Ordered removal, same as delete(): survivors keep their order.
    try testing.expectEqualSlices(i32, &[_]i32{ 1, 3 }, map.keys());
}

test "fetchDelete() of a missing key returns null and changes nothing" {
    var map = ZMap(i32, i32).init(testing.allocator);
    defer map.deinit();

    try map.set(1, 10);
    try testing.expect(map.fetchDelete(2) == null);
    try testing.expectEqual(@as(usize, 1), map.size());
}

test "fetchDelete() with an equal-but-distinct key returns the STORED key" {
    // []const u8 keys compare by content (SameValueZero over the bytes), so
    // a lookup key in a different buffer finds the entry -- and the caller
    // must get back the stored slice, not its own, to release the right one.
    var map = ZMap([]const u8, i32).init(testing.allocator);
    defer map.deinit();

    const stored = "key".*;
    var lookup = "key".*;
    try map.set(&stored, 42);

    const entry = map.fetchDelete(&lookup).?;
    try testing.expect(entry.key.ptr == &stored);
    try testing.expect(entry.key.ptr != &lookup);
    try testing.expectEqual(@as(i32, 42), entry.value);
    try testing.expectEqual(@as(usize, 0), map.size());
}
