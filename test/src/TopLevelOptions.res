@spice
type mystring = option<string>

@spice
type mystringTuple = (mystring, mystring)

@spice
type mystringVariant = MystringVariant(mystring)

@spice
type mystringArray = array<mystring>

@spice
type mystringList = list<mystring>

@spice
type mystringResult = result<mystring, string>

@spice
type optionRecord = {
  title: string,
  optionalAlias: option<mystring>,
  aliases: array<mystring>,
  tuple: (mystring, option<string>),
  result: result<mystring, option<string>>,
}

@spice
type maybeOptionRecord = option<optionRecord>

@spice
type nestedTuple = (
  maybeOptionRecord,
  optionRecord,
  mystring,
  option<string>,
  array<mystring>,
  result<mystring, option<string>>,
)

@spice
type nestedVariant =
  | Empty
  | Payload(mystring, option<string>, optionRecord)
  | MaybePayload(maybeOptionRecord)

@spice
type nestedContainer = {
  maybePayload: maybeOptionRecord,
  variant: nestedVariant,
  tuple: nestedTuple,
  variants: array<nestedVariant>,
  result: result<maybeOptionRecord, option<string>>,
}
