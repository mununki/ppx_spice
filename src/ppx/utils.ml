open Ppxlib
open Parsetree
open Ast_helper

let annotation_name = "spice"
let encoder_func_suffix = "_encode"
let value_encoder_func_suffix = "_encodeJson"
let decoder_func_suffix = "_decode"
let encoder_var_prefix = "encoder_"
let decoder_var_prefix = "decoder_"
let loc = !default_loc
let fail loc message = Location.raise_errorf ~loc "%s" message
let longident_parse = Longident.parse [@@ocaml.warning "-3"]
let mkloc txt loc = { Location.txt; loc }
let mknoloc txt = mkloc txt Location.none
let lid ?(loc = Location.none) s = mkloc (Longident.parse s) loc
let make_ident_expr ?attrs s = Exp.ident ?attrs (mknoloc (longident_parse s))

let tuple_or_singleton tuple l =
  match List.length l > 1 with true -> tuple l | false -> List.hd l

let get_attribute_by_name attributes name =
  let filtered =
    attributes
    |> List.filter (fun { attr_name = { Location.txt } } -> txt = name)
  in
  match filtered with
  | [] -> Ok None
  | [ attribute ] -> Ok (Some attribute)
  | _ -> Error ("Too many occurrences of \"" ^ name ^ "\" attribute")

type generator_settings = { do_encode : bool; do_decode : bool }

let make_generator_settings ~do_encode ~do_decode =
  { do_encode; do_decode }

let get_generator_settings_from_attributes attributes =
  match get_attribute_by_name attributes annotation_name with
  | Ok None -> (
      match
        ( get_attribute_by_name attributes (annotation_name ^ ".decode"),
          get_attribute_by_name attributes (annotation_name ^ ".encode") )
      with
      | Ok (Some _), Ok (Some _) ->
          Ok (Some (make_generator_settings ~do_encode:true ~do_decode:true))
      | Ok (Some _), Ok None ->
          Ok (Some (make_generator_settings ~do_encode:false ~do_decode:true))
      | Ok None, Ok (Some _) ->
          Ok (Some (make_generator_settings ~do_encode:true ~do_decode:false))
      | Ok None, Ok None -> Ok None
      | (Error _ as e), _ -> e
      | _, (Error _ as e) -> e)
  | Ok (Some _) ->
      Ok (Some (make_generator_settings ~do_encode:true ~do_decode:true))
  | Error _ as e -> e

let get_expression_from_payload { attr_name = { loc }; attr_payload = payload }
    =
  match payload with
  | PStr [ { pstr_desc } ] -> (
      match pstr_desc with
      | Pstr_eval (expr, _) -> expr
      | _ -> fail loc "Expected expression as attribute payload")
  | _ -> fail loc "Expected expression as attribute payload"

let get_param_names params =
  params
  |> List.map (fun ({ ptyp_desc; ptyp_loc }, _) ->
         match ptyp_desc with
         | Ptyp_var s -> s
         | _ ->
             fail ptyp_loc "Unhandled param type" |> fun v ->
             Location.Error v |> raise)

let get_string_from_expression { pexp_desc; pexp_loc } =
  match pexp_desc with
  | Pexp_constant const -> (
      match const with
      | Pconst_string _ -> Some const
      | Pconst_float _ -> None
      | _ -> fail pexp_loc "cannot find a name??")
  | _ -> fail pexp_loc "cannot find a name??"

let get_float_from_expression { pexp_desc; pexp_loc } =
  match pexp_desc with
  | Pexp_constant const -> (
      match const with
      | Pconst_string _ -> None
      | Pconst_float _ -> Some const
      | _ -> fail pexp_loc "cannot find a name??")
  | _ -> fail pexp_loc "cannot find a name??"

let index_const i =
  Pconst_string ("[" ^ string_of_int i ^ "]", Location.none, Some "*j")
  |> Exp.constant

let rec is_identifier_used_in_core_type type_name { ptyp_desc; ptyp_loc } =
  match ptyp_desc with
  | Ptyp_arrow (_, _, _) ->
      fail ptyp_loc "Can't generate codecs for function type"
  | Ptyp_any -> fail ptyp_loc "Can't generate codecs for `any` type"
  | Ptyp_package _ -> fail ptyp_loc "Can't generate codecs for module type"
  | Ptyp_variant (_, _, _) -> fail ptyp_loc "Unexpected Ptyp_variant"
  | Ptyp_var _ -> false
  | Ptyp_tuple child_types ->
      List.exists (is_identifier_used_in_core_type type_name) child_types
  | Ptyp_constr ({ txt }, child_types) -> (
      match txt = Lident type_name with
      | true -> true
      | false ->
          List.exists (is_identifier_used_in_core_type type_name) child_types)
  | _ -> fail ptyp_loc "This syntax is not yet handled by spice"

let attr_warning expr =
  {
    attr_name = mkloc "ocaml.warning" loc;
    attr_payload = PStr [ { pstr_desc = Pstr_eval (expr, []); pstr_loc = loc } ];
    attr_loc = loc;
  }

let attr_optional : Ppxlib.Parsetree.attribute =
  {
    attr_name = { txt = "res.optional"; loc = Location.none };
    attr_payload = PStr [];
    attr_loc = Location.none;
  }

let attr_partial : Ppxlib.Parsetree.attribute =
  {
    attr_name = { txt = "res.partial"; loc = Location.none };
    attr_payload = PStr [];
    attr_loc = Location.none;
  }

let expr_func ?(loc = Location.none) ~arity e =
  let attr_arity =
    Attr.mk { txt = "res.arity"; loc }
      (PStr [ Str.eval (Exp.constant (Const.int arity)) ])
  in
  Exp.construct ~attrs:[ attr_arity ] { txt = Lident "Function$"; loc } (Some e)

let ctyp_json_t = Typ.constr (mknoloc (Ldot (Lident "JSON", "t"))) []

let ctyp_arrow ?(loc = Location.none) ~arity ctyp =
  let arity = "Has_arity" ^ string_of_int arity in
  Typ.constr ~loc
    (mknoloc @@ Lident "function$")
    [ ctyp; Typ.variant [ Rf.tag (mknoloc arity) true [] ] Closed None ]

let check_option_type { ptyp_desc } =
  match ptyp_desc with
  | Ptyp_constr ({ txt = Lident "option" }, [ _ ]) -> true
  | _ -> false

let get_default_option_inner_type { ptyp_desc; ptyp_attributes } =
  match get_attribute_by_name ptyp_attributes "spice.codec" with
  | Ok None -> (
      match ptyp_desc with
      | Ptyp_constr ({ txt = Lident "option" }, [ inner_type ]) ->
          Some inner_type
      | _ -> None)
  | _ -> None
