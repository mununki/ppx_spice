@spice
type t = {
  label: string,
  value: int,
}

@spice
type t1 = {
  label: string,
  value: int,
}

@spice
type tOp = {
  label: option<string>,
  value?: int,
}

@spice
type t2 = {
  o: option<string>,
  n: Null.t<string>,
  on?: Null.t<string>,
  n2: Null.t<string>
}

@spice
type t3 = {
  @spice.default(0) value: int
  @spice.default(Some(1)) value2?: int
}

@spice
type t4 = {
  a: bigint,
  b?: bigint,
  c: option<bigint>,
}

@spice
type t5 = {
  maybeNull: option<Null.t<string>>,
}

// Types for testing nested error paths
@spice.decode
type inner = {value: int}

@spice.decode
type outer = {one: inner}

@spice.decode
type deeplyNested = {level1: outer}
