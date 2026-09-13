open Rescript_ppxlib

val generate_codecs :
  Utils.generator_settings ->
  Parsetree.constructor_declaration list ->
  bool ->
  Parsetree.expression option * Parsetree.expression option
