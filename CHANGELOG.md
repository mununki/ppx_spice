# CHANGELOG

# 0.4.2

- Add Linux arm64 release binaries and package installation support.

# 0.4.1

- Fix generated codecs for parameterized types so generic encoders and decoders can be partially applied in ReScript 12. https://github.com/mununki/ppx_spice/pull/123

# 0.4.0

- BREAKING: separate option encoders by JSON context. Top-level `option<T>` encoders now return `option<JSON.t>`, while fixed-position option values in tuples, variant payloads, arrays, lists, and results encode `None` as `JSON.Null`.
- Add generated `*_encodeJson` helpers for fixed JSON value contexts.
- Fix option encoding for nested top-level aliases, tuple fields, variant payloads, and `dict<option<T>>`. https://github.com/mununki/ppx_spice/pull/122
- Update examples to ESM output for direct Node execution with ReScript 12 runtime.

# 0.3.4

- migration to mununki

## 0.3.3

- fix: include nested error path in record field decode errors https://github.com/mununki/ppx_spice/pull/118
- Support `result`, `dict` types https://github.com/mununki/ppx_spice/pull/119

## 0.3.2

- Fixes O(n) nested match decoder replaces O(n²) tuple pattern matching to prevent the hang with the recode with many fields https://github.com/green-labs/ppx_spice/pull/111

## 0.3.1

- Fixes [#107](https://github.com/green-labs/ppx_spice/issues/107) Arrays being reversed by Spice.arrayFromJson

## 0.3.0

- BREAKING: changes to support rescript v12, will now generate codecs that use Stdlib instead of Js or Belt.
- Updates codec generation to handle the `result` type in addition to `Belt.Result.t`
- Polyvariant codecs no longer have an intermediate `Js.Json.tagged` type / function calls.
- Upgrade ocaml from v4.14.0 to v4.14.2 https://github.com/green-labs/ppx_spice/pull/101

## 0.2.9

- Update test project for compiler v12. https://github.com/green-labs/ppx_spice/pull/94
- Fix bigint codec on rescript v12. https://github.com/green-labs/ppx_spice/pull/93

## 0.2.8

- Dropped support for curried mode in accordance with compiler v12 changes.
- Fixed a build error in the polyvariant encoder generation function to ensure compatibility with compiler v12-alpha.12. https://github.com/green-labs/ppx_spice/pull/91

## 0.2.7

- Add type annotation to error pattern: now generates `Error(e: Spice.decodeError)` for record decoding errors.

## 0.2.6

- Fix compilation issue for records with a single field.

## 0.2.5

- Flat JSON decoders are now generated for records, with correct handling of optional and option fields. https://github.com/green-labs/ppx_spice/pull/88

## 0.2.4

- Fix critical performance issues for records with a large number of fields. https://github.com/green-labs/ppx_spice/pull/87

## 0.2.3

- Support the compiler v12-alpha.4 https://github.com/green-labs/ppx_spice/pull/82
- Support bigint type https://github.com/green-labs/ppx_spice/pull/83

## 0.2.2

- Support Null https://github.com/green-labs/ppx_spice/pull/80

## 0.2.1

- a190663 Utilize Js.Json.Boolean(bool) instead oif Js.Json.True, False https://github.com/green-labs/ppx_spice/pull/58
- a190663 Add support of uncurried mode for interface(*.resi) https://github.com/green-labs/ppx_spice/pull/58
- Support the compiler v11-rc.5 https://github.com/green-labs/ppx_spice/pull/61
- Add the feature of encoding/decoding between the number and (polymorphic)variant with `@spice.as` https://github.com/green-labs/ppx_spice/pull/64
- Fix generating encode, decode function when `@spice.as` with number https://github.com/green-labs/ppx_spice/pull/74

## 0.2.0

### Minor Changes

- 9ce55bf: Compat the untagged variant

## 0.2.0-next.0

### Minor Changes

- Compat the untagged variant

## 0.1.15

### Patch Changes

- 0e738ef: Support cli arg for uncurried mode

## 0.1.15-next.0

### Patch Changes

- Support cli arg for uncurried mode

# 0.1.14

- Support both `ns.optional` and `res.optional` for backward compatability

# 0.1.13

- Rename the attribute used for optional records from `ns.optional` to `res.optional`.

# 0.1.12

- Fix build error where `@spice.encode`, `@spice.decode` are used

# 0.1.11

- Build the executable with static linking for Linux with musl

# 0.1.10

- Build the executable with static linking for Linux

# 0.1.9

- Clean up npm publish files

# 0.1.8

- Fix type error where using tuple constructor type, such as `array<int>` for optional field in the record. https://github.com/green-labs/ppx_spice/pull/32

# 0.1.7

#### :rocket: New Feature

- Add support for the optional field record
- Add Windows platform support
