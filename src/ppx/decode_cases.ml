open Rescript_ppxlib
open Parsetree
open Ast_helper
open Utils

let generate_error_case ?(has_type_offset = false) numArgs i _ =
  let offset = if has_type_offset then 1 else 0 in
  {
    pc_bar = None;
    pc_lhs =
      Array.init numArgs (fun which ->
          match which == i with
          | true -> [%pat? Error (e : Spice.decodeError)]
          | false -> [%pat? _])
      |> Array.to_list
      |> tuple_or_singleton Pat.tuple;
    pc_guard = None;
    pc_rhs =
      [%expr Error { e with path = [%e index_const (i + offset)] ^ e.path }];
  }
