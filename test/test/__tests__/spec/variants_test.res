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
