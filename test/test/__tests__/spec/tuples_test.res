open Zora

let testEqual = (t, name, lhs, rhs) =>
  t->test(name, async t => {
    t->equal(lhs, rhs, name)
  })

zoraBlock("tuple with option", t => {
  let encodedSome = ("name", Some("nickname"))->Tuples.withOption_encode
  t->testEqual(
    `encode Some`,
    encodedSome,
    JSON.Array([JSON.String("name"), JSON.String("nickname")]),
  )

  let encodedNone = ("name", None)->Tuples.withOption_encode
  t->testEqual(`encode None`, encodedNone, JSON.Array([JSON.String("name"), JSON.Null]))

  let decodedSome = JSON.Array([JSON.String("name"), JSON.String("nickname")])->Tuples.withOption_decode
  t->testEqual(`decode Some`, decodedSome, Ok(("name", Some("nickname"))))

  let decodedNone = JSON.Array([JSON.String("name"), JSON.Null])->Tuples.withOption_decode
  t->testEqual(`decode None`, decodedNone, Ok(("name", None)))

  let decodedInvalid = JSON.Array([JSON.String("name"), JSON.Number(1.0)])->Tuples.withOption_decode
  t->test("decode invalid option payload includes tuple index", async t => {
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
