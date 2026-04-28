@spice
type stringDict = dict<string>

@spice
type intDict = dict<int>

@spice
type inner = {
  id: int,
  name: string,
}

@spice
type innerDict = dict<inner>

// Dict.t 형태 테스트
@spice
type dictT = Dict.t<string>

@spice
type optionStringDict = dict<option<string>>
