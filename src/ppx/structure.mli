open Rescript_ppxlib

val map_structure_item :
  < structure_item : Parsetree.structure_item -> Parsetree.structure_item ; .. > ->
  Parsetree.structure_item ->
  Parsetree.structure_item list
