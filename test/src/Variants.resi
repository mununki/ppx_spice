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

// Types for testing error paths
@spice.decode
type withArgs = WithArgs(int, string)
