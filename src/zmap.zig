//! Insertion-ordered maps with SameValueZero key comparison.
//! Keys and values are stored by value; callers own any referenced data.

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

/// Generic Map with ECMAScript-inspired key comparison. Array-backed (not a
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

        /// Create an empty map using `allocator` for its storage.
        pub fn init(allocator: Allocator) Self {
            return .{ .storage = .empty, .allocator = allocator };
        }

        /// Free map storage. Referenced keys and values remain caller-owned.
        pub fn deinit(self: *Self) void {
            self.storage.deinit(self.allocator);
        }

        /// Map.prototype.set() - unlike ZObject.set(), no frozen/writable/
        /// extensible checks (Map has no such concept). Setting an existing
        /// key updates its value WITHOUT moving its position in iteration
        /// order (only delete()+set() moves a key, to the end).
        /// Returns error.OutOfMemory if storage cannot grow.
        pub fn set(self: *Self, key: K, value: V) !void {
            try self.storage.put(self.allocator, key, value);
        }

        /// Return the value for `key`, or null if the key is absent.
        pub fn get(self: *const Self, key: K) ?V {
            return self.storage.get(key);
        }

        /// Return whether `key` exists using SameValueZero comparison.
        pub fn has(self: *const Self, key: K) bool {
            return self.storage.contains(key);
        }

        /// Map.prototype.delete() - ordered: preserves the relative order of
        /// surviving entries. Returns true if the key existed.
        pub fn delete(self: *Self, key: K) bool {
            return self.storage.orderedRemove(key);
        }

        /// Like delete(), but hands back the entry that was removed -- the
        /// key and value as STORED, which may be a different (equal) object
        /// than the `key` passed in. Ownership of both moves to the caller.
        /// Returns null if the key wasn't present. Same ordered removal as
        /// delete().
        pub fn fetchDelete(self: *Self, key: K) ?Entry {
            const kv = self.storage.fetchOrderedRemove(key) orelse return null;
            return .{ .key = kv.key, .value = kv.value };
        }

        /// Remove all entries while retaining allocated capacity.
        pub fn clear(self: *Self) void {
            self.storage.clearRetainingCapacity();
        }

        /// Return the number of entries.
        pub fn size(self: *const Self) usize {
            return self.storage.count();
        }

        /// Borrowed mutable keys in insertion order, not an ECMAScript iterator.
        /// Do not modify keys; structural mutations invalidate this view.
        pub fn keys(self: *const Self) []K {
            return self.storage.keys();
        }

        /// Borrowed mutable values in insertion order, not an ECMAScript iterator.
        /// Structural mutations invalidate this view.
        pub fn values(self: *const Self) []V {
            return self.storage.values();
        }

        /// A key of type K and its associated value of type V.
        pub const Entry = struct { key: K, value: V };

        /// Snapshot of entries in insertion order. Caller frees the
        /// returned slice with `allocator`.
        /// Returns error.OutOfMemory if the snapshot cannot be allocated.
        pub fn entries(self: *const Self, allocator: Allocator) ![]Entry {
            const ks = self.storage.keys();
            const vs = self.storage.values();
            const list = try allocator.alloc(Entry, ks.len);
            for (ks, vs, 0..) |k, v, i| list[i] = .{ .key = k, .value = v };
            return list;
        }

        /// Visit entries in insertion order with (context, key, value).
        /// Callbacks must not structurally mutate the map.
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
        /// Duplicate keys update their value at the first insertion position.
        /// Returns error.OutOfMemory and frees partial storage on allocation failure.
        pub fn fromSlice(allocator: Allocator, pairs: []const Entry) !Self {
            var map = Self.init(allocator);
            errdefer map.deinit();
            for (pairs) |pair| try map.set(pair.key, pair.value);
            return map;
        }
    };
}
