@spice
type mystring0 = option<string>

let encoding0 = (str): option<JSON.t> => {
  str->mystring0_encode
}

@spice
type mystring1 = {content: option<string>}

let encoding1 = (str): JSON.t => {
  str->mystring1_encode
}

let a: option<JSON.t> = encoding0(None)
Console.log(a)
