# Spice

A ReScript PPX, which generates JSON (de)serializers.

`Spice` is originated from

- The `Spice melange` in the novel, Dune
- A flavor for the (polymorphic) variant

> This PPX is highly influenced by [Decco](https://github.com/reasonml-labs/decco) and developed with forking the source codes of Decco. Spice has implemented all the features of Decco@1.5.0 and additional useful features for the (polymorphic) variant of its own.

## Motivation

1. Parse the string instead of the array to the (polymorphic) variant

To parse the JSON data, [Decco](https://github.com/reasonml-labs/decco) is being heavily used in many projects. But, there's a restriction to parse the JSON string into a (polymorphic) variant with the Decco. The JSON data should be formed in an array. It is obvious at some point. But generally, we face the string data which needs to be parsed into the variant in most use cases.

Whenever it is needed to parse the response in Json, the custom encoder/decoder functions are needed to parse the Json string into the (polymorphic) variant with Decco. But you don't need to write it with the Spice as long as you add `@spice.as` in (polymorphic) variants.

with Decco

```rescript
@decco
type status = WAITING | PROCESSING | SUCCESS | FAIL

let encoderStatus = v =>
  switch v {
  | WAITING => "waiting"
  | PROCESSING => "processing"
  | SUCCESS => "success"
  | FAIL => "fail"
  }->Js.Json.string

let decoderStatus = json => {
  switch json |> Js.Json.classify {
  | Js.Json.JSONString(str) =>
    switch str {
    | "waiting" => WAITING->Ok
    | "processing" => PROCESSING->Ok
    | "success" => SUCCESS->Ok
    | "fail" => FAIL->Ok
    | _ => Error({Decco.path: "", message: "Expected JSONString", value: json})
    }
  | _ => Error({Decco.path: "", message: "Expected JSONString", value: json})
  }
}

let codecStatus: Decco.codec<status> = (encoderStatus, decoderStatus)


@decco
type data = {
  status: @decco.codec(codecStatus) status,
}
```

with Spice

```rescript
@spice
type status =
  | @spice.as("waiting") WAITING
  | @spice.as("processing") PROCESSING
  | @spice.as("success") SUCCESS
  | @spice.as("fail") FAIL

@spice
type data = {
  status: status,
}
```

2. Parse/stringify the Unicode string

There are many cases to parse and stringify the string data into (polymorphic) variants. Furthermore, the Unicode string needs to be handled with a variant. Currently, pattern matching is not working for the Unicode string in ReScript, the Spice is using `if ... then ... else` to compare the Unicode string in case of adding `@spice.as` attribute.

3. Last but not least, Spice supports the latest ReScript compilers: v10's optional field record, v11's untagged variant, and more.

## Example

1. Variant

```rescript
@spice
type t = | @spice.as(`하나`) One | @spice.as(`second`) Two

// automatically generated
let t_encode = ...

// automatically generated
let t_decode = ...

let encoded = One->t_encode // Js.Json.string(`하나`)

let decoded = Js.Json.string(`second`)->t_decode // Ok(Two)
```

2. Record

```rescript
@spice
type t = {
  @spice.key("spice-label") label: string,
  @spice.key("spice-value") value: int,
}

let sample = Js.Dict.empty()
sample->Js.Dict.set("spice-label", Js.Json.string("sample"))
sample->Js.Dict.set("spice-value", Js.Json.number(1.0))
let sampleJson = sample->Js.Json.object_

let sampleRecord: t = {
  label: "sample",
  value: 1,
}


let encoded = sampleRecord->Records.t_encode // sampleJson

let decoded = sampleJson->Records.t_decode // Ok(sampleRecord)
```

## Getting Started

Read our [Guide with examples](docs/GUIDE.md)

## Install

### Compatibility on the compiler versions

| Compiler      | Ppx_spice             | Note                          |
| ------------- | --------------------- | ----------------------------- |
| v12           | v0.3.0 >=             |                               |
| v12-alpha.14  | v0.2.9 >=             | Bigint.fromFloat type changed |
| v12-alpha.5   | v0.2.8                | Curried mode deprecated       |
| v12-alpha.4   | v0.2.7 >= && > v0.2.2 |                               |
| v11           | v0.2.2 >= && > v0.2.0 |                               |
| v10           | v0.2.0 >=             |                               |

NOTE: Starting from v0.2.8, support for curried mode is discontinued to align with the changes in compiler v12.

The `feature/new-ppxlib` branch targets ReScript 12's released `Parsetree` directly through `rescript-ppxlib` 1.x. Until the native PPX ABI is available in an official compiler release, this branch requires the companion ReScript 12 compiler fork with `-rescript-ppx` / `rescript-ppx-flags` support.

```sh
yarn add -D @mununki/ppx-spice
```

```json
// bsconfig.json

"bs-dependencies": [
  "@mununki/ppx-spice"
],
"rescript-ppx-flags": [
  ...,
  "@mununki/ppx-spice/ppx"
],
```

## Development

### With Dune

Make sure running the below commands in `/src`.

1. Create a sandbox with opam

```
opam switch create spice 5.3.0
```

2. Install dependencies

```
opam pin add rescript-ppxlib /absolute/path/to/rescript-ppxlib
opam install . --deps-only
```

3. Build

```
dune build
```

4. Test

Make sure running tests in `/test`

```
cd test

(install dependencies)
pnpm install

(build --watch)
pnpm res:clean && pnpm res:watch

(run test --watch)
pnpm test:watch
```
