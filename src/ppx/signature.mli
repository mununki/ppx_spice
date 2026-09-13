open Rescript_ppxlib

val map_signature_item :
  < signature_item : Parsetree.signature_item -> Parsetree.signature_item ; .. > ->
  Parsetree.signature_item ->
  Parsetree.signature_item list
