@spice
type profile = {
  name: string,
  nickname: option<string>,
  middleName: option<Null.t<string>>,
  title?: string,
}

@spice
type nameParts = (string, option<string>)

@spice
type event = Renamed(option<string>)

@spice
type maybeName = option<string>

let profileWithoutOptionalValues: profile = {
  name: "Alice",
  nickname: None,
  middleName: None,
}

let profileWithoutOptionalValuesJson: JSON.t = profileWithoutOptionalValues->profile_encode

let profileWithJsonNull: profile = {
  name: "Alice",
  nickname: None,
  middleName: Some(Null.Null),
}

let profileWithJsonNullJson: JSON.t = profileWithJsonNull->profile_encode

let missingRecordFields = %raw(`
  {
    "name": "Alice"
  }
`)

let missingRecordFieldsResult: result<profile, Spice.decodeError> =
  missingRecordFields->profile_decode

let presentNullRecordField = %raw(`
  {
    "name": "Alice",
    "nickname": null
  }
`)

let presentNullRecordFieldError: result<profile, Spice.decodeError> =
  presentNullRecordField->profile_decode

let tupleWithNone: nameParts = ("Alice", None)
let tupleWithNoneJson: JSON.t = tupleWithNone->nameParts_encode

let tupleNullPayload = %raw(`["Alice", null]`)
let tupleNullPayloadResult: result<nameParts, Spice.decodeError> =
  tupleNullPayload->nameParts_decode

let eventWithNone: event = Renamed(None)
let eventWithNoneJson: JSON.t = eventWithNone->event_encode

let eventNullPayload = %raw(`["Renamed", null]`)
let eventNullPayloadResult: result<event, Spice.decodeError> =
  eventNullPayload->event_decode

let topLevelSomeJson: option<JSON.t> = Some("Alice")->maybeName_encode

let topLevelNoneJson: option<JSON.t> = None->maybeName_encode
