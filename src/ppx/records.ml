open Ppxlib
open Parsetree
open Ast_helper
open Utils

type parsed_decl = {
  name : string;
  (* "NAME" *)
  key : expression;
  (* v.NAME *)
  field : expression;
  codecs : expression option * expression option;
  default : expression option;
  is_optional : bool;
  is_option : bool;
}

let generate_encoder decls unboxed =
  match unboxed with
  | true ->
      let { codecs; field } = List.hd decls in
      let e, _ = codecs in
      Utils.expr_func ~arity:1 [%expr fun v -> [%e Option.get e] [%e field]]
  | false ->
      let arrExpr =
        decls
        |> List.map
             (fun { key; field; codecs = encoder, _; is_optional; is_option } ->
               if is_optional || is_option then
                 Exp.tuple
                   [ key; Exp.apply (Option.get encoder) [ (Nolabel, field) ] ]
               else
                 [%expr
                   [%e key],
                     (* The Encoder for option `Spice.optionToJson` returns option type.
                          So, encoder for other types return with Some to match type of encoder. *)
                     Some ([%e Option.get encoder] [%e field])])
        |> Exp.array
      in
      Exp.constraint_
        [%expr JSON.Object (Dict.fromArray (Spice.filterOptional [%e arrExpr]))]
        Utils.ctyp_json_t
      |> Exp.fun_ Asttypes.Nolabel None [%pat? v]
      |> Utils.expr_func ~arity:1

(* O(n) nested match decoder - replaces O(n²) tuple pattern matching *)
let generate_nested_decoder decls =
  let loc = !default_loc in
  let dict_expr = Exp.ident (mknoloc (Longident.Lident "dict")) in

  (* Build the final Ok expression with the record *)
  let ok_expr =
    let record_fields =
      List.map
        (fun d ->
          let { name; is_optional } = d in
          let attrs = if is_optional then [ Utils.attr_optional ] else [] in
          (lid name, make_ident_expr ~attrs name))
        decls
    in
    [%expr Ok [%e Exp.record record_fields None]]
  in

  (* Generate decode expression for a single field *)
  let generate_decode_expr d =
    let { key; codecs; default; is_optional; is_option; _ } = d in
    match codecs with
    | _, Some decode ->
        let get_expr = [%expr Dict.get [%e dict_expr] [%e key]] in
        let decode_applied = [%expr [%e decode]] in
        let opt_map = [%expr Option.map [%e get_expr] [%e decode_applied]] in
        (match (is_optional, is_option, default) with
        | _, _, Some d -> [%expr Option.getOr [%e opt_map] (Ok [%e d])]
        | true, _, None -> [%expr Option.getOr [%e opt_map] (Ok None)]
        | _, true, None -> [%expr Option.getOr [%e opt_map] (Ok None)]
        | _, _, None ->
            [%expr
              Option.getOr [%e opt_map] (Spice.error ([%e key] ^ " missing") v)])
    | _ -> [%expr Spice.error ([%e key] ^ " missing") v]
  in

  (* Build nested matches from the last field backwards *)
  let build_nested_matches decls inner_expr =
    let rec loop acc = function
      | [] -> acc
      | d :: rest ->
          let { name; key; _ } = d in
          let decode_expr = generate_decode_expr d in
          let var_pat = Pat.var (mknoloc name) in
          let ok_case =
            Exp.case
              (Pat.construct (mknoloc (Longident.Lident "Ok")) (Some var_pat))
              acc
          in
          let error_case =
            Exp.case
              (Pat.construct
                 (mknoloc (Longident.Lident "Error"))
                 (Some
                    (Pat.constraint_
                       (Pat.var (mknoloc "e"))
                       (Typ.constr
                          (mknoloc (Longident.parse "Spice.decodeError"))
                          []))))
              [%expr Spice.error ~path:("." ^ [%e key] ^ e.path) e.message e.value]
          in
          let match_expr = Exp.match_ decode_expr [ ok_case; error_case ] in
          loop match_expr rest
    in
    loop inner_expr (List.rev decls)
  in

  build_nested_matches decls ok_expr

let generate_nested_switches decls =
  generate_nested_decoder decls

let generate_decoder decls unboxed =
  match unboxed with
  | true ->
      let { codecs; name } = List.hd decls in
      let _, d = codecs in

      let record_expr = Exp.record [ (lid name, make_ident_expr "v") ] None in

      Utils.expr_func ~arity:1
        [%expr
          fun v -> Result.map ([%e Option.get d] v) (fun v -> [%e record_expr])]
  | false ->
      Utils.expr_func ~arity:1
        [%expr
          fun v ->
            match (v : JSON.t) with
            | JSON.Object dict -> [%e generate_nested_switches decls]
            | _ -> Spice.error "Not an object" v]

let wrap_decoder_with_some decode =
  let wrap_some = Utils.expr_func ~arity:1 [%expr fun v -> Some(v)] in
  Utils.expr_func ~arity:1
    [%expr fun json -> Result.map ([%e decode] json) [%e wrap_some]]

let make_omittable_codecs codecs =
  let add_attrs attrs e = { e with pexp_attributes = attrs } in
  match codecs with
  | Some encode, Some decode ->
      ( Some
          (add_attrs [ Utils.attr_partial ]
             [%expr Spice.optionalToJson [%e encode]]),
        Some (wrap_decoder_with_some decode) )
  | Some encode, None ->
      ( Some
          (add_attrs [ Utils.attr_partial ]
             [%expr Spice.optionalToJson [%e encode]]),
        None )
  | None, Some decode -> (None, Some (wrap_decoder_with_some decode))
  | None, None -> codecs

let parse_decl generator_settings
    { pld_name = { txt }; pld_loc; pld_type; pld_attributes } =
  let default =
    match get_attribute_by_name pld_attributes "spice.default" with
    | Ok (Some attribute) -> Some (get_expression_from_payload attribute)
    | Ok None -> None
    | Error s -> fail pld_loc s
  in
  let key =
    match get_attribute_by_name pld_attributes "spice.key" with
    | Ok (Some attribute) -> get_expression_from_payload attribute
    | Ok None -> Exp.constant (Pconst_string (txt, Location.none, Some "*j"))
    | Error s -> fail pld_loc s
  in
  let optional_attrs = [ "ns.optional"; "res.optional" ] in
  let is_optional =
    optional_attrs
    |> List.map (fun attr -> get_attribute_by_name pld_attributes attr)
    |> List.exists (function Ok (Some _) -> true | _ -> false)
  in
  let is_option = Utils.check_option_type pld_type in
  let codecs = Codecs.generate_codecs generator_settings pld_type in
  let codecs =
    if is_optional then
      make_omittable_codecs codecs
    else if is_option then
      match pld_type.ptyp_desc with
      | Ptyp_constr ({ txt = Lident "option" }, [ inner_type ]) ->
          make_omittable_codecs
            (Codecs.generate_codecs generator_settings inner_type)
      | _ -> codecs
    else codecs
  in

  {
    name = txt;
    key;
    field = Exp.field [%expr v] (lid txt);
    codecs;
    default;
    is_optional;
    is_option;
  }

let generate_codecs ({ do_encode; do_decode } as generator_settings) decls
    unboxed =
  let parsed_decls = List.map (parse_decl generator_settings) decls in
  ( (if do_encode then Some (generate_encoder parsed_decls unboxed) else None),
    if do_decode then Some (generate_decoder parsed_decls unboxed) else None )
