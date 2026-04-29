open Zora

let testEqual = (t, name, lhs, rhs) =>
  t->test(name, async t => {
    t->equal(lhs, rhs, name)
  })

let dataObject: GenericTypeParams.dataObject<string> = {
  properties: ["one", "two"],
}

let dataObjectJson = JSON.Object(dict{
  "properties": JSON.Array([JSON.String("one"), JSON.String("two")]),
})

let pairObject: GenericTypeParams.pairObject<string, int> = {
  left: "count",
  right: 42,
}

let pairObjectJson = JSON.Object(dict{
  "left": JSON.String("count"),
  "right": JSON.Number(42.0),
})

let nestedObject: GenericTypeParams.nestedObject<string> = {
  items: [dataObject],
  selected: Some("one"),
}

let nestedObjectJson = JSON.Object(dict{
  "items": JSON.Array([dataObjectJson]),
  "selected": JSON.String("one"),
})

zoraBlock("generic type parameter codecs", t => {
  t->testEqual(
    `encode generic record`,
    (
      GenericTypeParams.dataObject_encode :> (
        string => JSON.t
      ) => GenericTypeParams.dataObject<string> => JSON.t
    )(Spice.stringToJson)(dataObject),
    dataObjectJson,
  )

  t->testEqual(
    `decode generic record`,
    (
      GenericTypeParams.dataObject_decode :> (
        JSON.t => result<string, Spice.decodeError>
      ) => JSON.t => result<GenericTypeParams.dataObject<string>, Spice.decodeError>
    )(Spice.stringFromJson)(dataObjectJson),
    Ok(dataObject),
  )

  t->testEqual(
    `encode record with two generic params`,
    (
      GenericTypeParams.pairObject_encode :> (
        string => JSON.t
      ) => (int => JSON.t) => GenericTypeParams.pairObject<string, int> => JSON.t
    )(Spice.stringToJson)(Spice.intToJson)(pairObject),
    pairObjectJson,
  )

  t->testEqual(
    `decode record with two generic params`,
    (
      GenericTypeParams.pairObject_decode :> (
        JSON.t => result<string, Spice.decodeError>
      ) => (
        JSON.t => result<int, Spice.decodeError>
      ) => JSON.t => result<GenericTypeParams.pairObject<string, int>, Spice.decodeError>
    )(Spice.stringFromJson)(Spice.intFromJson)(pairObjectJson),
    Ok(pairObject),
  )

  t->testEqual(
    `encode nested generic record`,
    (
      GenericTypeParams.nestedObject_encode :> (
        string => JSON.t
      ) => GenericTypeParams.nestedObject<string> => JSON.t
    )(Spice.stringToJson)(nestedObject),
    nestedObjectJson,
  )

  t->testEqual(
    `decode nested generic record`,
    (
      GenericTypeParams.nestedObject_decode :> (
        JSON.t => result<string, Spice.decodeError>
      ) => JSON.t => result<GenericTypeParams.nestedObject<string>, Spice.decodeError>
    )(Spice.stringFromJson)(nestedObjectJson),
    Ok(nestedObject),
  )
})
