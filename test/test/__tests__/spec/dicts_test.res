open Zora

let testEqual = (t, name, lhs, rhs) =>
  t->test(name, async t => {
    t->equal(lhs, rhs, name)
  })

zoraBlock("dict<string>", t => {
  let data: dict<string> = dict{"key1": "value1", "key2": "value2"}
  let json = JSON.Object(dict{"key1": JSON.String("value1"), "key2": JSON.String("value2")})

  let encoded = data->Dicts.stringDict_encode
  t->testEqual("encode string dict", encoded, json)

  let decoded = json->Dicts.stringDict_decode
  t->testEqual("decode string dict", decoded, Ok(data))
})

zoraBlock("dict<int>", t => {
  let data: dict<int> = dict{"a": 1, "b": 2, "c": 3}
  let json = JSON.Object(dict{
    "a": JSON.Number(1.0),
    "b": JSON.Number(2.0),
    "c": JSON.Number(3.0),
  })

  let encoded = data->Dicts.intDict_encode
  t->testEqual("encode int dict", encoded, json)

  let decoded = json->Dicts.intDict_decode
  t->testEqual("decode int dict", decoded, Ok(data))
})

zoraBlock("dict<inner>", t => {
  let data: dict<Dicts.inner> = dict{
    "first": {Dicts.id: 1, name: "Alice"},
    "second": {Dicts.id: 2, name: "Bob"},
  }
  let json = JSON.Object(dict{
    "first": JSON.Object(dict{"id": JSON.Number(1.0), "name": JSON.String("Alice")}),
    "second": JSON.Object(dict{"id": JSON.Number(2.0), "name": JSON.String("Bob")}),
  })

  let encoded = data->Dicts.innerDict_encode
  t->testEqual("encode inner dict", encoded, json)

  let decoded = json->Dicts.innerDict_decode
  t->testEqual("decode inner dict", decoded, Ok(data))
})

zoraBlock("empty dict", t => {
  let data: dict<string> = dict{}
  let json = JSON.Object(dict{})

  let encoded = data->Dicts.stringDict_encode
  t->testEqual("encode empty dict", encoded, json)

  let decoded = json->Dicts.stringDict_decode
  t->testEqual("decode empty dict", decoded, Ok(data))
})

zoraBlock("Dict.t<string>", t => {
  let data: Dict.t<string> = dict{"foo": "bar"}
  let json = JSON.Object(dict{"foo": JSON.String("bar")})

  let encoded = data->Dicts.dictT_encode
  t->testEqual("encode Dict.t", encoded, json)

  let decoded = json->Dicts.dictT_decode
  t->testEqual("decode Dict.t", decoded, Ok(data))
})

zoraBlock("dict<option<string>>", t => {
  let data: Dicts.optionStringDict = dict{
    "present": Some("value"),
    "missing": None,
  }
  let encoded = data->Dicts.optionStringDict_encode
  t->testEqual(
    "encode omits None values",
    encoded,
    JSON.Object(dict{"present": JSON.String("value")}),
  )

  let decoded =
    JSON.Object(dict{
      "present": JSON.String("value"),
      "missing": JSON.Null,
    })->Dicts.optionStringDict_decode

  t->test("decode present null values as None", async t => {
    switch decoded {
    | Ok(dict) => {
        t->equal(dict->Dict.get("present"), Some(Some("value")), "present")
        let hasOwnProperty: (Dicts.optionStringDict, string) => bool = %raw(
          `(obj, key) => Object.prototype.hasOwnProperty.call(obj, key)`
        )
        let getValue: (Dicts.optionStringDict, string) => option<string> = %raw(
          `(obj, key) => obj[key]`
        )
        let hasMissing = hasOwnProperty(dict, "missing")
        let missingValue = getValue(dict, "missing")
        t->equal(hasMissing, true, "missing key is present")
        t->equal(missingValue, None, "missing")
      }
    | Error(_) => t->fail("expected decode to succeed")
    }
  })
})
