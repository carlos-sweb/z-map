# Z-Map

[![Zig Version](https://img.shields.io/badge/zig-0.16-orange.svg)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Generic, insertion-ordered, ECMAScript-compatible **Map** implementation in Zig 0.16, part of the [z-*](https://github.com/carlos-sweb) micro-library ecosystem.

## Design

`ZMap(K, V)` is array-backed (`std.array_hash_map.Custom`, not a plain hashmap), so iteration order is always insertion order — the full ECMA-262 `Map` ordering rule, which is simpler than `Object`'s (no array-index-keys-first partitioning; pure insertion order for every key type). Keys/values are compared with **SameValueZero** (`zequality.sameValueZero`/`zequality.hash` — see [z-equality](https://github.com/carlos-sweb/z-equality)): `NaN` equals `NaN`, `+0` equals `-0`.

Unlike `ZObject(T)` (always String-keyed, so it duplicates keys), `ZMap(K, V)` stores `K`/`V` by value exactly as given — the caller manages the lifetime of any reference-typed `K`/`V` (e.g. `[]const u8`), same convention as `ZArray(T)`.

## API

| Method | ECMAScript Equivalent |
|---|---|
| `set(key, value)` | `Map.prototype.set()` — updates value in place without moving position if the key already exists |
| `get(key)` | `Map.prototype.get()` |
| `has(key)` | `Map.prototype.has()` |
| `delete(key)` | `Map.prototype.delete()` — ordered; re-adding a deleted key moves it to the end |
| `clear()` | `Map.prototype.clear()` |
| `size()` | `Map.prototype.size` |
| `keys()` / `values()` | `Map.prototype.keys()` / `values()` |
| `entries(allocator)` | `Map.prototype.entries()` |
| `forEach(context, callback)` | `Map.prototype.forEach()` |
| `fromSlice(allocator, pairs)` | construct from `[]const Entry{key, value}` |

## Testing

```bash
zig build test
```

## License

MIT
