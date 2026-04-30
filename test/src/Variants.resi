@spice
type t = One | Two

@spice
type t1 = One1 | Two1

@spice @unboxed
type t2 = One2(int)

@spice @unboxed
type t3 = One3(int)

@spice
type t4 = | @spice.as(1.0) One | @spice.as(2.0) Two

@spice
type withOption = WithOption(option<string>)

@spice
type optionPayloadVariant =
  | A
  | B(option<string>)

@spice
type inlineRecordPayload =
  | InlineBoo({a: string})
  | InlineBar({x: bool})

@spice
type inlineRecordWithOptional = InlineOptional({
  name: string,
  maybe: option<string>,
  optional?: string,
})

@spice
type inlineRecordWithAttrs = InlineAttrs({
  @spice.key("user_id") id: string,
  @spice.default("anonymous") name: string,
})

@spice
type inlineRecordGeneric<'a> = InlineGeneric({value: 'a})

@spice @unboxed
type inlineRecordUnboxed = InlineUnboxed({a: string})

@spice @unboxed
type inlineRecordUnboxedMany = InlineUnboxedMany({a: string, b: int})

// Types for testing error paths
@spice.decode
type withArgs = WithArgs(int, string)
