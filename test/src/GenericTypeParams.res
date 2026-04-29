@spice
type dataObject<'data> = {properties: array<'data>}

@spice
type pairObject<'left, 'right> = {
  left: 'left,
  right: 'right,
}

@spice
type nestedObject<'data> = {
  items: array<dataObject<'data>>,
  selected: option<'data>,
}
