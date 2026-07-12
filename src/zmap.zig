const std = @import("std");
const Allocator = std.mem.Allocator;
const zequality = @import("zequality");

/// std.array_hash_map.Custom Context adapter (3-arg eql, u32 hash — a
/// different shape from std.HashMap's 2-arg Context) backed by
/// zequality.sameValueZero/zequality.hash, matching ECMAScript's Map/Set key
/// comparison (SameValueZero: NaN equals NaN, +0 equals -0).
fn MapContext(comptime K: type) type {
    return struct {
        pub fn hash(self: @This(), k: K) u32 {
            _ = self;
            return @truncate(zequality.hash(K, k));
        }
        pub fn eql(self: @This(), a: K, b: K, b_index: usize) bool {
            _ = self;
            _ = b_index;
            return zequality.sameValueZero(K, a, b);
        }
    };
}

/// Generic ECMAScript-compatible Map implementation. Array-backed (not a
/// plain hashmap) so iteration order is insertion order, per ECMA-262 Map
/// semantics — simpler than Object's OrdinaryOwnPropertyKeys (no
/// array-index-keys-first partitioning; Map order is pure insertion order
/// for every key type).
///
/// Unlike ZObject(T) (always String-keyed, so it duplicates keys), ZMap(K,V)
/// stores K/V by value exactly as given — the caller manages the lifetime of
/// any reference-typed K/V (e.g. []const u8), same convention as ZArray(T).
pub fn ZMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        storage: std.array_hash_map.Custom(K, V, MapContext(K), false),
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return .{ .storage = .empty, .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.storage.deinit(self.allocator);
        }

        /// Map.prototype.set() - unlike ZObject.set(), no frozen/writable/
        /// extensible checks (Map has no such concept). Setting an existing
        /// key updates its value WITHOUT moving its position in iteration
        /// order (only delete()+set() moves a key, to the end).
        pub fn set(self: *Self, key: K, value: V) !void {
            try self.storage.put(self.allocator, key, value);
        }

        pub fn get(self: *const Self, key: K) ?V {
            return self.storage.get(key);
        }

        pub fn has(self: *const Self, key: K) bool {
            return self.storage.contains(key);
        }

        /// Map.prototype.delete() - ordered: preserves the relative order of
        /// surviving entries. Returns true if the key existed.
        pub fn delete(self: *Self, key: K) bool {
            return self.storage.orderedRemove(key);
        }

        pub fn clear(self: *Self) void {
            self.storage.clearRetainingCapacity();
        }

        pub fn size(self: *const Self) usize {
            return self.storage.count();
        }

        /// Map.prototype.keys() - insertion order.
        pub fn keys(self: *const Self) []K {
            return self.storage.keys();
        }

        /// Map.prototype.values() - insertion order.
        pub fn values(self: *const Self) []V {
            return self.storage.values();
        }

        pub const Entry = struct { key: K, value: V };

        /// Map.prototype.entries() - insertion order. Caller frees the
        /// returned slice with `allocator`.
        pub fn entries(self: *const Self, allocator: Allocator) ![]Entry {
            const ks = self.storage.keys();
            const vs = self.storage.values();
            const list = try allocator.alloc(Entry, ks.len);
            for (ks, vs, 0..) |k, v, i| list[i] = .{ .key = k, .value = v };
            return list;
        }

        /// Map.prototype.forEach() - insertion order.
        pub fn forEach(
            self: *const Self,
            context: anytype,
            comptime callback: fn (@TypeOf(context), K, V) void,
        ) void {
            const ks = self.storage.keys();
            const vs = self.storage.values();
            for (ks, vs) |k, v| callback(context, k, v);
        }

        /// Build a ZMap from a slice of {key, value} pairs, in order.
        pub fn fromSlice(allocator: Allocator, pairs: []const Entry) !Self {
            var map = Self.init(allocator);
            errdefer map.deinit();
            for (pairs) |pair| try map.set(pair.key, pair.value);
            return map;
        }
    };
}
