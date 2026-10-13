# Z-Map

[![Zig Version](https://img.shields.io/badge/zig-0.17-orange.svg)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Generic, insertion-ordered **Map** implementation with ECMAScript-inspired key comparison in Zig 0.17, part of the [z-*](https://github.com/carlos-sweb) micro-library ecosystem. It implements core ordered-map behavior, but is not a fully conforming ECMAScript Map.

## Design

`ZMap(K, V)` is array-backed (`std.array_hash_map.Custom`, not a plain hashmap), so iteration order is always insertion order — the full ECMA-262 `Map` ordering rule, which is simpler than `Object`'s (no array-index-keys-first partitioning; pure insertion order for every key type). Keys/values are compared with **SameValueZero** (`zequality.sameValueZero`/`zequality.hash` — see [z-equality](https://github.com/carlos-sweb/z-equality)): `NaN` equals `NaN`, `+0` equals `-0`.

Unlike `ZObject(T)` (always String-keyed, so it duplicates keys), `ZMap(K, V)` stores `K`/`V` by value exactly as given — the caller manages the lifetime of any reference-typed `K`/`V` (e.g. `[]const u8`), same convention as `ZArray(T)`.

## API

[Browse the generated API documentation](https://carlos-sweb.github.io/z-map/).

| Method | ECMAScript Equivalent |
|---|---|
| `set(key, value)` | `Map.prototype.set()` — updates value in place without moving position if the key already exists |
| `get(key)` | `Map.prototype.get()` |
| `has(key)` | `Map.prototype.has()` |
| `delete(key)` | `Map.prototype.delete()` — ordered; re-adding a deleted key moves it to the end |
| `fetchDelete(key)` | ordered removal returning the stored key/value pair, or null |
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

The `z-equality` dependency is fetched automatically from GitHub, pinned to
a specific commit and package hash in `build.zig.zon`.

## API documentation

Generate the API reference with Zig's documentation generator:

```bash
zig build docs
python3 -m http.server 8000 --directory zig-out/docs
```

Open `http://localhost:8000/` to browse it. GitHub Actions runs the tests,
generates the documentation, and publishes it to GitHub Pages on each push
to `master`. Pull requests validate tests and documentation without publishing.

## ECMAScript compatibility limits

Reviewed against [ECMA-262 Map Objects](https://tc39.es/ecma262/multipage/keyed-collections.html#sec-map-objects).
Insertion order, duplicate-key updates, deletion/reinsertion order, and
SameValueZero lookup for floating-point keys are covered by tests.

- `set(-0.0, value)` preserves the negative sign in exposed keys.
- `keys()` and `values()` expose mutable borrowed storage; changing keys can
  invalidate lookup. Structural mutations invalidate these views.
- `entries()` returns an allocated snapshot. There are no live Map iterators.
- `forEach` calls `(context, key, value)` and requires that callbacks do not
  structurally mutate the map. Adding entries can invalidate storage; deleting
  entries can cause callbacks to read removed storage.
- `set` returns `!void`, and `get` returns `?V`; these are Zig API conventions.
- Pointer keys use identity; slices and arrays use content equality, and
  plain structs use field equality. Represent JS objects with identity-bearing
  pointers or a suitable custom `eql`/`hash` pair. Arbitrary Zig key types do not
  automatically implement the ECMAScript value model.
- The ECMAScript constructor/iterable protocol, prototype properties, symbols,
  runtime receiver checks, and `Map.groupBy` are not implemented. The current
  specification draft's `getOrInsert` and `getOrInsertComputed` are also absent.

## License

MIT
