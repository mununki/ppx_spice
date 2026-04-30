val generate_codecs :
  Utils.generator_settings ->
  Parsetree.label_declaration list ->
  bool ->
  Parsetree.expression option * Parsetree.expression option

val generate_inline_record_encoder_expr :
  Utils.generator_settings ->
  Parsetree.label_declaration list ->
  Parsetree.expression

val generate_inline_record_decoder_expr :
  Utils.generator_settings ->
  Parsetree.label_declaration list ->
  string ->
  Parsetree.expression
