open Ppxlib
open Parsetree
open Utils

let ctyp_optional_json_t =
  Ast_helper.Typ.constr (mknoloc (Longident.Lident "option"))
    [ Utils.ctyp_json_t ]

let rec add_encoder_params param_names result_type =
  match param_names with
  | [] -> result_type
  | hd :: tl ->
      [%type: ([%t Ast_helper.Typ.var hd] -> JSON.t) -> [%t result_type]]
      |> Utils.ctyp_arrow ~arity:1 |> add_encoder_params tl

let make_result_type value_type =
  [%type: ([%t value_type], Spice.decodeError) result]

let rec add_decoder_params param_names result_type =
  match param_names with
  | [] -> result_type
  | hd :: tl ->
      let decoder_param =
        [%type: JSON.t -> [%t make_result_type (Ast_helper.Typ.var hd)]]
        |> Utils.ctyp_arrow ~arity:1
      in
      [%type: [%t decoder_param] -> [%t result_type]]
      |> Utils.ctyp_arrow ~arity:1 |> add_decoder_params tl

let generate_sig_decls { do_encode; do_decode } type_name param_names
    encoder_result_type ~has_value_encoder =
  let encoder_pat = type_name ^ Utils.encoder_func_suffix in
  let value_encoder_pat = type_name ^ Utils.value_encoder_func_suffix in
  let decoder_pat = type_name ^ Utils.decoder_func_suffix in
  let value_type =
    param_names
    |> List.map Ast_helper.Typ.var
    |> Ast_helper.Typ.constr (lid type_name)
  in

  let decls = [] in

  let decls =
    match do_encode with
    | true ->
        let decls =
          decls
          @ [
            [%type: [%t value_type] -> [%t encoder_result_type]]
            |> Utils.ctyp_arrow ~arity:1
            |> add_encoder_params (List.rev param_names)
            |> Ast_helper.Val.mk (mknoloc encoder_pat)
            |> Ast_helper.Sig.value;
          ]
        in
        if has_value_encoder then
          decls
          @ [
              [%type: [%t value_type] -> JSON.t]
              |> Utils.ctyp_arrow ~arity:1
              |> add_encoder_params (List.rev param_names)
              |> Ast_helper.Val.mk (mknoloc value_encoder_pat)
              |> Ast_helper.Sig.value;
            ]
        else decls
    | false -> decls
  in
  let decls =
    match do_decode with
    | true ->
        decls
        @ [
            [%type: JSON.t -> [%t make_result_type value_type]]
            |> Utils.ctyp_arrow ~arity:1
            |> add_decoder_params (List.rev param_names)
            |> Ast_helper.Val.mk (mknoloc decoder_pat)
            |> Ast_helper.Sig.value;
          ]
    | false -> decls
  in

  decls

let map_type_decl decl =
  let {
    ptype_attributes;
    ptype_name = { txt = type_name };
    ptype_manifest;
    ptype_params;
    ptype_loc;
  } =
    decl
  in

  match get_generator_settings_from_attributes ptype_attributes with
  | Error s -> fail ptype_loc s
  | Ok None -> []
  | Ok (Some generator_settings) ->
      let encoder_result_type =
        match ptype_manifest with
        | Some manifest -> (
            match Utils.get_default_option_inner_type manifest with
            | Some _ -> ctyp_optional_json_t
            | None -> [%type: JSON.t])
        | None -> [%type: JSON.t]
      in
      generate_sig_decls generator_settings type_name
        (get_param_names ptype_params)
        encoder_result_type ~has_value_encoder:true

let map_signature_item mapper ({ psig_desc } as signature_item) =
  match psig_desc with
  | Psig_type (_, decls) ->
      let generated_sig_items =
        decls |> List.map map_type_decl |> List.concat
      in
      mapper#signature_item signature_item :: generated_sig_items
  | _ -> [ mapper#signature_item signature_item ]
