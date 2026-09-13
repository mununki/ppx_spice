open Rescript_ppxlib

val generate_codecs :
  Utils.generator_settings ->
  Parsetree.row_field list ->
  bool ->
  Parsetree.expression option * Parsetree.expression option
