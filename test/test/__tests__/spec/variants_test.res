open Zora

let testEqual = (t, name, lhs, rhs) =>
  t->test(name, async t => {
    t->equal(lhs, rhs, name)
  })

zoraBlock("variants with @spice.as", t => {
  let variantEncoded = Variants.One->Variants.t_encode
  t->testEqual(`encode 하나`, variantEncoded, JSON.Number(1.))

  let variantEncoded = Variants.Two->Variants.t_encode
  t->testEqual(`encode 둘`, variantEncoded, JSON.String(`둘`))

  let variantDecoded = JSON.Number(1.)->Variants.t_decode
  t->testEqual(`decode 하나`, variantDecoded, Ok(Variants.One))

  let variantDecoded = JSON.String(`둘`)->Variants.t_decode
  t->testEqual(`decode 둘`, variantDecoded, Ok(Variants.Two))
})

zoraBlock(`variants without @spice.as`, t => {
  let variantEncoded = Variants.One1->Variants.t1_encode
  t->testEqual(`encode One1`, variantEncoded, JSON.Array([JSON.String(`One1`)]))

  let variantEncoded = Variants.Two1->Variants.t1_encode
  t->testEqual(`encode Two1`, variantEncoded, JSON.Array([JSON.String(`Two1`)]))

  let variantDecoded = JSON.Array([JSON.String(`One1`)])->Variants.t1_decode
  t->testEqual(`decode ["One1"]`, variantDecoded, Ok(Variants.One1))

  let variantDecoded = JSON.Array([JSON.String(`Two1`)])->Variants.t1_decode
  t->testEqual(`decode ["Two1"]`, variantDecoded, Ok(Variants.Two1))
})

zoraBlock("unboxed variants with @spice.as", t => {
  let variantEncoded = Variants.One2(0)->Variants.t2_encode
  t->testEqual(`encode 하나`, variantEncoded, JSON.Number(0.0))

  let variantDecoded = JSON.Number(0.0)->Variants.t2_decode
  t->testEqual(`decode 하나`, variantDecoded, Ok(Variants.One2(0)))
})

zoraBlock(`unboxed variants without @spice.as`, t => {
  let variantEncoded = Variants.One3(0)->Variants.t3_encode
  t->testEqual(`encode One3(0)`, variantEncoded, JSON.Number(0.0))

  let variantDecoded = JSON.Number(0.0)->Variants.t3_decode
  t->testEqual(`decode 0`, variantDecoded, Ok(Variants.One3(0)))
})

zoraBlock("variants with @spice.as number", t => {
  let variantEncoded = Variants.One->Variants.t4_encode
  t->testEqual(`encode 1.0`, variantEncoded, JSON.Number(1.0))

  let variantEncoded = Variants.Two->Variants.t4_encode
  t->testEqual(`encode 2.0`, variantEncoded, JSON.Number(2.0))

  let variantDecoded = JSON.Number(1.0)->Variants.t4_decode
  t->testEqual(`decode 1.0`, variantDecoded, Ok(Variants.One))

  let variantDecoded = JSON.Number(2.0)->Variants.t4_decode
  t->testEqual(`decode 2.0`, variantDecoded, Ok(Variants.Two))
})

zoraBlock("variant payload with option", t => {
  let encodedSome = Variants.WithOption(Some("value"))->Variants.withOption_encode
  t->testEqual(
    `encode Some`,
    encodedSome,
    JSON.Array([JSON.String("WithOption"), JSON.String("value")]),
  )

  let encoded = Variants.WithOption(None)->Variants.withOption_encode
  t->testEqual(`encode None`, encoded, JSON.Array([JSON.String("WithOption"), JSON.Null]))

  let decodedSome =
    JSON.Array([JSON.String("WithOption"), JSON.String("value")])->Variants.withOption_decode
  t->testEqual(`decode Some`, decodedSome, Ok(Variants.WithOption(Some("value"))))

  let decoded = JSON.Array([JSON.String("WithOption"), JSON.Null])->Variants.withOption_decode
  t->testEqual(`decode None`, decoded, Ok(Variants.WithOption(None)))

  let decodedInvalid =
    JSON.Array([JSON.String("WithOption"), JSON.Number(1.0)])->Variants.withOption_decode
  t->test("decode invalid option payload includes variant payload index", async t => {
    switch decodedInvalid {
    | Error({path, message, value}) => {
        t->equal(path, "[1]", "path")
        t->equal(message, "Not a string", "message")
        t->equal(value, JSON.Number(1.0), "value")
      }
    | Ok(_) => t->fail("expected decode to fail")
    }
  })
})

zoraBlock("variant with payloadless and option payload constructors", t => {
  let encodedA = Variants.A->Variants.optionPayloadVariant_encode
  t->testEqual(`encode A`, encodedA, JSON.Array([JSON.String("A")]))

  let encodedSome = Variants.B(Some("value"))->Variants.optionPayloadVariant_encode
  t->testEqual(`encode B Some`, encodedSome, JSON.Array([JSON.String("B"), JSON.String("value")]))

  let encodedNone = Variants.B(None)->Variants.optionPayloadVariant_encode
  t->testEqual(`encode B None`, encodedNone, JSON.Array([JSON.String("B"), JSON.Null]))

  let decodedA = JSON.Array([JSON.String("A")])->Variants.optionPayloadVariant_decode
  t->testEqual(`decode A`, decodedA, Ok(Variants.A))

  let decodedSome =
    JSON.Array([JSON.String("B"), JSON.String("value")])->Variants.optionPayloadVariant_decode
  t->testEqual(`decode B Some`, decodedSome, Ok(Variants.B(Some("value"))))

  let decodedNone = JSON.Array([JSON.String("B"), JSON.Null])->Variants.optionPayloadVariant_decode
  t->testEqual(`decode B None`, decodedNone, Ok(Variants.B(None)))

  let decodedInvalid =
    JSON.Array([JSON.String("B"), JSON.Number(1.0)])->Variants.optionPayloadVariant_decode
  t->test("decode invalid B option payload includes payload index", async t => {
    switch decodedInvalid {
    | Error({path, message, value}) => {
        t->equal(path, "[1]", "path")
        t->equal(message, "Not a string", "message")
        t->equal(value, JSON.Number(1.0), "value")
      }
    | Ok(_) => t->fail("expected decode to fail")
    }
  })
})

zoraBlock("variant with inline record payload", t => {
  let encodedBoo = Variants.InlineBoo({a: "Bo"})->Variants.inlineRecordPayload_encode
  t->testEqual(
    `encode InlineBoo`,
    encodedBoo,
    JSON.Array([JSON.String("InlineBoo"), JSON.Object(dict{"a": JSON.String("Bo")})]),
  )

  let decodedBoo =
    JSON.Array([JSON.String("InlineBoo"), JSON.Object(dict{"a": JSON.String("Bo")})])
    ->Variants.inlineRecordPayload_decode
  t->testEqual(`decode InlineBoo`, decodedBoo, Ok(Variants.InlineBoo({a: "Bo"})))

  let encodedBar = Variants.InlineBar({x: true})->Variants.inlineRecordPayload_encode
  t->testEqual(
    `encode InlineBar`,
    encodedBar,
    JSON.Array([JSON.String("InlineBar"), JSON.Object(dict{"x": JSON.Boolean(true)})]),
  )

  let decodedBar =
    JSON.Array([JSON.String("InlineBar"), JSON.Object(dict{"x": JSON.Boolean(true)})])
    ->Variants.inlineRecordPayload_decode
  t->testEqual(`decode InlineBar`, decodedBar, Ok(Variants.InlineBar({x: true})))
})

zoraBlock("variant inline record payload field errors include payload index", t => {
  let decodedInvalid =
    JSON.Array([JSON.String("InlineBoo"), JSON.Object(dict{"a": JSON.Number(1.0)})])
    ->Variants.inlineRecordPayload_decode

  t->test("decode invalid inline record field includes [1] path prefix", async t => {
    switch decodedInvalid {
    | Error({path, message, value}) => {
        t->equal(path, "[1].a", "path")
        t->equal(message, "Not a string", "message")
        t->equal(value, JSON.Number(1.0), "value")
      }
    | Ok(_) => t->fail("expected decode to fail")
    }
  })

  let decodedMissing =
    JSON.Array([JSON.String("InlineBoo"), JSON.Object(dict{})])
    ->Variants.inlineRecordPayload_decode

  t->test("decode missing inline record field includes [1] path prefix", async t => {
    switch decodedMissing {
    | Error({path, message, value}) => {
        t->equal(path, "[1].a", "path")
        t->equal(message, "a missing", "message")
        t->equal(value, JSON.Object(dict{}), "value")
      }
    | Ok(_) => t->fail("expected decode to fail")
    }
  })
})

zoraBlock("variant inline record payload optional fields", t => {
  let value = Variants.InlineOptional({name: "payload", maybe: None})
  let json = JSON.Array([
    JSON.String("InlineOptional"),
    JSON.Object(dict{"name": JSON.String("payload")}),
  ])

  let encoded = value->Variants.inlineRecordWithOptional_encode
  t->testEqual(`encode omitted inline record option fields`, encoded, json)

  let decoded = json->Variants.inlineRecordWithOptional_decode
  t->test("decode omitted inline record option fields", async t => {
    switch decoded {
    | Ok(Variants.InlineOptional({name, maybe, optional: ?optional})) => {
        t->equal(name, "payload", "name")
        t->equal(maybe, None, "maybe")
        t->equal(optional, None, "optional")
      }
    | Error(_) => t->fail("expected decode to succeed")
    }
  })

  let value = Variants.InlineOptional({
    name: "payload",
    maybe: Some("maybe"),
    optional: "optional",
  })
  let json = JSON.Array([
    JSON.String("InlineOptional"),
    JSON.Object(dict{
      "name": JSON.String("payload"),
      "maybe": JSON.String("maybe"),
      "optional": JSON.String("optional"),
    }),
  ])

  let encoded = value->Variants.inlineRecordWithOptional_encode
  t->testEqual(`encode present inline record option fields`, encoded, json)

  let decoded = json->Variants.inlineRecordWithOptional_decode
  t->testEqual(`decode present inline record option fields`, decoded, Ok(value))
})

zoraBlock("variant inline record payload field attributes", t => {
  let value = Variants.InlineAttrs({id: "u1", name: "Ada"})
  let json = JSON.Array([
    JSON.String("InlineAttrs"),
    JSON.Object(dict{"user_id": JSON.String("u1"), "name": JSON.String("Ada")}),
  ])

  let encoded = value->Variants.inlineRecordWithAttrs_encode
  t->testEqual(`encode inline record @spice.key`, encoded, json)

  let decoded = json->Variants.inlineRecordWithAttrs_decode
  t->testEqual(`decode inline record @spice.key`, decoded, Ok(value))

  let defaultJson = JSON.Array([
    JSON.String("InlineAttrs"),
    JSON.Object(dict{"user_id": JSON.String("u1")}),
  ])
  let decodedDefault = defaultJson->Variants.inlineRecordWithAttrs_decode
  t->testEqual(
    `decode inline record @spice.default`,
    decodedDefault,
    Ok(Variants.InlineAttrs({id: "u1", name: "anonymous"})),
  )

  let decodedInvalid =
    JSON.Array([JSON.String("InlineAttrs"), JSON.Object(dict{"user_id": JSON.Number(1.0)})])
    ->Variants.inlineRecordWithAttrs_decode
  t->test("decode invalid keyed inline record field uses JSON key in path", async t => {
    switch decodedInvalid {
    | Error({path, message, value}) => {
        t->equal(path, "[1].user_id", "path")
        t->equal(message, "Not a string", "message")
        t->equal(value, JSON.Number(1.0), "value")
      }
    | Ok(_) => t->fail("expected decode to fail")
    }
  })
})

zoraBlock("variant inline record payload generic field", t => {
  let value: Variants.inlineRecordGeneric<int> = Variants.InlineGeneric({value: 42})
  let json = JSON.Array([
    JSON.String("InlineGeneric"),
    JSON.Object(dict{"value": JSON.Number(42.0)}),
  ])

  let encoded =
    (
      Variants.inlineRecordGeneric_encode :> (
        int => JSON.t
      ) => Variants.inlineRecordGeneric<int> => JSON.t
    )(Spice.intToJson)(value)
  t->testEqual(`encode generic inline record payload`, encoded, json)

  let decoded =
    (
      Variants.inlineRecordGeneric_decode :> (
        JSON.t => result<int, Spice.decodeError>
      ) => JSON.t => result<Variants.inlineRecordGeneric<int>, Spice.decodeError>
    )(Spice.intFromJson)(json)
  t->testEqual(`decode generic inline record payload`, decoded, Ok(value))
})

zoraBlock("unboxed variant with inline record payload", t => {
  let encoded = Variants.InlineUnboxed({a: "Bo"})->Variants.inlineRecordUnboxed_encode
  t->testEqual(`encode unboxed inline record`, encoded, JSON.Object(dict{"a": JSON.String("Bo")}))

  let decoded = JSON.Object(dict{"a": JSON.String("Bo")})->Variants.inlineRecordUnboxed_decode
  t->testEqual(`decode unboxed inline record`, decoded, Ok(Variants.InlineUnboxed({a: "Bo"})))

  let many = Variants.InlineUnboxedMany({a: "Bo", b: 1})
  let manyJson = JSON.Object(dict{"a": JSON.String("Bo"), "b": JSON.Number(1.0)})
  let encodedMany = many->Variants.inlineRecordUnboxedMany_encode
  t->testEqual(`encode unboxed inline record with multiple fields`, encodedMany, manyJson)

  let decodedMany = manyJson->Variants.inlineRecordUnboxedMany_decode
  t->testEqual(`decode unboxed inline record with multiple fields`, decodedMany, Ok(many))
})

zoraBlock("variant error path includes correct index", t => {
  // Variant with args: ["WithArgs", int, string]
  // Index 0 is the constructor name, index 1 is the int, index 2 is the string
  // When index 1 fails, path should be "[1]" not "[0]"
  let invalidJson = JSON.Array([
    JSON.String("WithArgs"),
    JSON.String("not an int"), // should be int at index 1
    JSON.String("valid string"),
  ])

  let decoded = invalidJson->Variants.withArgs_decode
  t->test("error path shows [1] for first argument", async t => {
    switch decoded {
    | Error({path}) => t->equal(path, "[1]", "path should be [1]")
    | Ok(_) => t->fail("expected decode to fail")
    }
  })
})
