open Zora

let testEqual = (t, name, lhs, rhs) =>
  t->test(name, async t => {
    t->equal(lhs, rhs, name)
  })

let optionRecord = (): TopLevelOptions.optionRecord => {
  title: "payload",
  optionalAlias: Some(None),
  aliases: [Some("alias"), None],
  tuple: (Some("tuple"), None),
  result: Error(None),
}

let optionRecordJson = () =>
  JSON.Object(dict{
    "title": JSON.String("payload"),
    "optionalAlias": JSON.Null,
    "aliases": JSON.Array([JSON.String("alias"), JSON.Null]),
    "tuple": JSON.Array([JSON.String("tuple"), JSON.Null]),
    "result": JSON.Array([JSON.String("Error"), JSON.Null]),
  })

let nestedTuple = (): TopLevelOptions.nestedTuple => (
  Some(optionRecord()),
  optionRecord(),
  None,
  Some("plain"),
  [Some("array"), None],
  Ok(Some("result")),
)

let nestedTupleJson = () =>
  JSON.Array([
    optionRecordJson(),
    optionRecordJson(),
    JSON.Null,
    JSON.String("plain"),
    JSON.Array([JSON.String("array"), JSON.Null]),
    JSON.Array([JSON.String("Ok"), JSON.String("result")]),
  ])

let payloadVariantJson = () =>
  JSON.Array([JSON.String("Payload"), JSON.Null, JSON.Null, optionRecordJson()])

zoraBlock("top-level option", t => {
  let encodedSome: option<JSON.t> = Some("value")->TopLevelOptions.mystring_encode
  t->testEqual(`encode Some`, encodedSome, Some(JSON.String("value")))

  let encodedNone: option<JSON.t> = None->TopLevelOptions.mystring_encode
  t->testEqual(`encode None`, encodedNone, None)

  let decodedSome = JSON.String("value")->TopLevelOptions.mystring_decode
  t->testEqual(`decode Some`, decodedSome, Ok(Some("value")))

  let decodedNone = JSON.Null->TopLevelOptions.mystring_decode
  t->testEqual(`decode null`, decodedNone, Ok(None))
})

zoraBlock("top-level option of nested record", t => {
  let payload = optionRecord()
  let payloadJson = optionRecordJson()

  let encodedSome: option<JSON.t> = Some(payload)->TopLevelOptions.maybeOptionRecord_encode
  t->testEqual(`encode Some nested record`, encodedSome, Some(payloadJson))

  let encodedNone: option<JSON.t> = None->TopLevelOptions.maybeOptionRecord_encode
  t->testEqual(`encode None as absence`, encodedNone, None)

  let encodedJsonSome: JSON.t = Some(payload)->TopLevelOptions.maybeOptionRecord_encodeJson
  t->testEqual(`encodeJson Some nested record`, encodedJsonSome, payloadJson)

  let encodedJsonNone: JSON.t = None->TopLevelOptions.maybeOptionRecord_encodeJson
  t->testEqual(`encodeJson None as null`, encodedJsonNone, JSON.Null)

  let decodedSome = payloadJson->TopLevelOptions.maybeOptionRecord_decode
  t->testEqual(`decode Some nested record`, decodedSome, Ok(Some(payload)))

  let decodedNone = JSON.Null->TopLevelOptions.maybeOptionRecord_decode
  t->testEqual(`decode null`, decodedNone, Ok(None))
})

zoraBlock("top-level option alias in fixed JSON contexts", t => {
  let tupleEncoded = (Some("value"), None)->TopLevelOptions.mystringTuple_encode
  t->testEqual(
    `encode tuple alias None as null`,
    tupleEncoded,
    JSON.Array([JSON.String("value"), JSON.Null]),
  )

  let variantEncoded =
    TopLevelOptions.MystringVariant(None)->TopLevelOptions.mystringVariant_encode
  t->testEqual(
    `encode variant alias None as null`,
    variantEncoded,
    JSON.Array([JSON.String("MystringVariant"), JSON.Null]),
  )

  let arrayEncoded = [Some("value"), None]->TopLevelOptions.mystringArray_encode
  t->testEqual(
    `encode array alias None as null`,
    arrayEncoded,
    JSON.Array([JSON.String("value"), JSON.Null]),
  )

  let listEncoded = List.fromArray([Some("value"), None])->TopLevelOptions.mystringList_encode
  t->testEqual(
    `encode list alias None as null`,
    listEncoded,
    JSON.Array([JSON.String("value"), JSON.Null]),
  )

  let resultEncoded = Ok(None)->TopLevelOptions.mystringResult_encode
  t->testEqual(
    `encode result alias None as null`,
    resultEncoded,
    JSON.Array([JSON.String("Ok"), JSON.Null]),
  )
})

zoraBlock("nested record option contexts", t => {
  let encoded = optionRecord()->TopLevelOptions.optionRecord_encode
  t->testEqual(`encode record with nested option alias`, encoded, optionRecordJson())

  let decoded = optionRecordJson()->TopLevelOptions.optionRecord_decode
  t->testEqual(`decode record with nested option alias`, decoded, Ok(optionRecord()))

  let omittedRecord: TopLevelOptions.optionRecord = {
    title: "payload",
    optionalAlias: None,
    aliases: [],
    tuple: (None, None),
    result: Ok(None),
  }
  let omittedJson = JSON.Object(dict{
    "title": JSON.String("payload"),
    "aliases": JSON.Array([]),
    "tuple": JSON.Array([JSON.Null, JSON.Null]),
    "result": JSON.Array([JSON.String("Ok"), JSON.Null]),
  })

  let encodedOmitted = omittedRecord->TopLevelOptions.optionRecord_encode
  t->testEqual(`encode omitted outer option field`, encodedOmitted, omittedJson)

  let decodedOmitted = omittedJson->TopLevelOptions.optionRecord_decode
  t->testEqual(`decode missing outer option field`, decodedOmitted, Ok(omittedRecord))
})

zoraBlock("nested tuple, variant, and container option contexts", t => {
  let tupleEncoded = nestedTuple()->TopLevelOptions.nestedTuple_encode
  t->testEqual(`encode nested tuple`, tupleEncoded, nestedTupleJson())

  let tupleDecoded = nestedTupleJson()->TopLevelOptions.nestedTuple_decode
  t->testEqual(`decode nested tuple`, tupleDecoded, Ok(nestedTuple()))

  let payloadVariant = TopLevelOptions.Payload(None, None, optionRecord())
  let variantEncoded = payloadVariant->TopLevelOptions.nestedVariant_encode
  t->testEqual(`encode nested variant payload`, variantEncoded, payloadVariantJson())

  let variantDecoded = payloadVariantJson()->TopLevelOptions.nestedVariant_decode
  t->testEqual(`decode nested variant payload`, variantDecoded, Ok(payloadVariant))

  let maybeVariant = TopLevelOptions.MaybePayload(None)
  let maybeVariantJson = JSON.Array([JSON.String("MaybePayload"), JSON.Null])
  let maybeVariantEncoded = maybeVariant->TopLevelOptions.nestedVariant_encode
  t->testEqual(`encode nested variant option alias`, maybeVariantEncoded, maybeVariantJson)

  let maybeVariantDecoded = maybeVariantJson->TopLevelOptions.nestedVariant_decode
  t->testEqual(`decode nested variant option alias`, maybeVariantDecoded, Ok(maybeVariant))

  let container: TopLevelOptions.nestedContainer = {
    maybePayload: None,
    variant: payloadVariant,
    tuple: nestedTuple(),
    variants: [
      TopLevelOptions.Empty,
      maybeVariant,
      TopLevelOptions.Payload(Some("variant"), Some("plain"), optionRecord()),
    ],
    result: Ok(None),
  }
  let containerJson = JSON.Object(dict{
    "maybePayload": JSON.Null,
    "variant": payloadVariantJson(),
    "tuple": nestedTupleJson(),
    "variants": JSON.Array([
      JSON.Array([JSON.String("Empty")]),
      maybeVariantJson,
      JSON.Array([
        JSON.String("Payload"),
        JSON.String("variant"),
        JSON.String("plain"),
        optionRecordJson(),
      ]),
    ]),
    "result": JSON.Array([JSON.String("Ok"), JSON.Null]),
  })

  let containerEncoded = container->TopLevelOptions.nestedContainer_encode
  t->testEqual(`encode nested container`, containerEncoded, containerJson)

  let containerDecoded = containerJson->TopLevelOptions.nestedContainer_decode
  t->testEqual(`decode nested container`, containerDecoded, Ok(container))
})
