val generate_codecs :
  Utils.generator_settings ->
  Parsetree.core_type ->
  Parsetree.expression option * Parsetree.expression option

val generate_value_codecs :
  Utils.generator_settings ->
  Parsetree.core_type ->
  Parsetree.expression option * Parsetree.expression option
