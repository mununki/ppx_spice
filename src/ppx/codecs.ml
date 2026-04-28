open Ppxlib
open Parsetree
open Ast_helper
open Utils

type encode_context = Optional_context | Value_context

let apply_partial func args =
  args
  |> List.map (fun e -> (Asttypes.Nolabel, e))
  |> Exp.apply ~attrs:[ attr_partial ] func

let is_dict_identifier = function
  | Longident.Lident "dict"
  | Ldot (Ldot (Lident "Js", "Dict"), "t")
  | Ldot (Lident "Dict", "t") ->
      true
  | _ -> false

let rec parameterize_value_codecs type_args encoder_func decoder_func
    generator_settings =
  let sub_encoders, sub_decoders =
    type_args
    |> List.map (fun core_type ->
           generate_codecs_for Value_context generator_settings core_type)
    |> List.split
  in
  ( (match encoder_func with
    | None -> None
    | Some encoder_func ->
        sub_encoders
        |> List.map (fun e -> (Asttypes.Nolabel, Option.get e))
        |> Exp.apply ~attrs:[ attr_partial ] encoder_func
        |> Option.some),
    match decoder_func with
    | None -> None
    | Some decoder_func ->
        sub_decoders
        |> List.map (fun e -> (Asttypes.Nolabel, Option.get e))
        |> Exp.apply ~attrs:[ attr_partial ] decoder_func
        |> Option.some )

and generate_constr_codecs context { do_encode; do_decode; _ }
    { Location.txt = identifier; loc } =
  let open Longident in
  match identifier with
  | Lident "string" ->
      ( (if do_encode then Some [%expr Spice.stringToJson] else None),
        if do_decode then Some [%expr Spice.stringFromJson] else None )
  | Lident "int" ->
      ( (if do_encode then Some [%expr Spice.intToJson] else None),
        if do_decode then Some [%expr Spice.intFromJson] else None )
  | Lident "bigint" ->
      ( (if do_encode then Some [%expr Spice.bigintToJson] else None),
        if do_decode then Some [%expr Spice.bigintFromJson] else None )
  | Lident "float" ->
      ( (if do_encode then Some [%expr Spice.floatToJson] else None),
        if do_decode then Some [%expr Spice.floatFromJson] else None )
  | Lident "bool" ->
      ( (if do_encode then Some [%expr Spice.boolToJson] else None),
        if do_decode then Some [%expr Spice.boolFromJson] else None )
  | Lident "unit" ->
      ( (if do_encode then Some [%expr Spice.unitToJson] else None),
        if do_decode then Some [%expr Spice.unitFromJson] else None )
  | Lident "array" ->
      ( (if do_encode then Some [%expr Spice.arrayToJson] else None),
        if do_decode then Some [%expr Spice.arrayFromJson] else None )
  | Lident "list" ->
      ( (if do_encode then Some [%expr Spice.listToJson] else None),
        if do_decode then Some [%expr Spice.listFromJson] else None )
  | Lident "option" ->
      ( (if do_encode then
           match context with
           | Optional_context -> Some [%expr Spice.optionToJson]
           | Value_context -> Some [%expr Spice.optionToNullableJson]
         else None),
        if do_decode then Some [%expr Spice.optionFromJson] else None )
  | Ldot (Lident "Js", "null")
  | Ldot (Ldot (Lident "Js", "Null"), "t")
  | Ldot (Lident "Null", "t") ->
      ( (if do_encode then Some [%expr Spice.nullToJson] else None),
        if do_decode then Some [%expr Spice.nullFromJson] else None )
  | Lident "result"
  | Ldot (Lident "Result", "t")
  | Ldot (Ldot (Lident "Belt", "Result"), "t") ->
      ( (if do_encode then Some [%expr Spice.resultToJson] else None),
        if do_decode then Some [%expr Spice.resultFromJson] else None )
  | Lident "dict"
  | Ldot (Ldot (Lident "Js", "Dict"), "t")
  | Ldot (Lident "Dict", "t") ->
      ( (if do_encode then Some [%expr Spice.dictToJson] else None),
        if do_decode then Some [%expr Spice.dictFromJson] else None )
  | Ldot (Ldot (Lident "Js", "Json"), "t") | Ldot (Lident "JSON", "t") ->
      ( (if do_encode then Some (Utils.expr_func ~arity:1 [%expr fun v -> v])
         else None),
        if do_decode then Some (Utils.expr_func ~arity:1 [%expr fun v -> Ok v])
        else None )
  | Lident s ->
      ( (if do_encode then
           let suffix =
             match context with
             | Value_context -> Utils.value_encoder_func_suffix
             | _ -> Utils.encoder_func_suffix
           in
           Some (make_ident_expr (s ^ suffix))
         else None),
        if do_decode then Some (make_ident_expr (s ^ Utils.decoder_func_suffix))
        else None )
  | Ldot (left, right) ->
      ( (if do_encode then
           let suffix =
             match context with
             | Value_context -> Utils.value_encoder_func_suffix
             | Optional_context -> Utils.encoder_func_suffix
           in
           Some
             (Exp.ident
                (mknoloc (Ldot (left, right ^ suffix))))
         else None),
        if do_decode then
          Some
            (Exp.ident
               (mknoloc (Ldot (left, right ^ Utils.decoder_func_suffix))))
        else None )
  | Lapply (_, _) -> fail loc "Lapply syntax not yet handled by spice"

and generate_dict_codecs ({ do_encode; do_decode } as generator_settings)
    value_type =
  match Utils.get_default_option_inner_type value_type with
  | Some inner_type ->
      let inner_encode, inner_decode =
        generate_codecs_for Value_context generator_settings inner_type
      in
      let optional_value_encoder =
        apply_partial [%expr Spice.optionToJson] [ Option.get inner_encode ]
      in
      let value_decoder =
        apply_partial [%expr Spice.optionFromJson] [ Option.get inner_decode ]
      in
      ( (if do_encode then
           Some (apply_partial [%expr Spice.dictOptionalToJson] [ optional_value_encoder ])
         else None),
        if do_decode then
          Some (apply_partial [%expr Spice.dictFromJson] [ value_decoder ])
        else None )
  | None ->
      parameterize_value_codecs [ value_type ]
        (if do_encode then Some [%expr Spice.dictToJson] else None)
        (if do_decode then Some [%expr Spice.dictFromJson] else None)
        generator_settings

and generate_codecs_for context
    ({ do_encode; do_decode } as generator_settings)
    { ptyp_desc; ptyp_loc; ptyp_attributes } =
  match ptyp_desc with
  | Ptyp_any -> fail ptyp_loc "Can't generate codecs for `any` type"
  | Ptyp_arrow (_, _, _) ->
      fail ptyp_loc "Can't generate codecs for function type"
  | Ptyp_package _ -> fail ptyp_loc "Can't generate codecs for module type"
  | Ptyp_tuple types ->
      let composite_codecs =
        List.map (generate_codecs_for Value_context generator_settings) types
      in
      ( (if do_encode then
           Some
             (composite_codecs
             |> List.map (fun (e, _) -> Option.get e)
             |> Tuple.generate_encoder)
         else None),
        if do_decode then
          Some
            (composite_codecs
            |> List.map (fun (_, d) -> Option.get d)
            |> Tuple.generate_decoder)
        else None )
  | Ptyp_var s ->
      ( (if do_encode then Some (make_ident_expr (encoder_var_prefix ^ s))
         else None),
        if do_decode then Some (make_ident_expr (decoder_var_prefix ^ s))
        else None )
  | Ptyp_constr (constr, typeArgs) -> (
      let custom_codec = get_attribute_by_name ptyp_attributes "spice.codec" in
      match (custom_codec, is_dict_identifier constr.txt, typeArgs) with
      | Ok None, true, [ value_type ] ->
          generate_dict_codecs generator_settings value_type
      | _ ->
      let encode, decode =
        match custom_codec with
        | Ok None -> generate_constr_codecs context generator_settings constr
        | Ok (Some attribute) ->
            let expr = get_expression_from_payload attribute in
            ( (if do_encode then
                 Some
                   [%expr
                     let e, _ = [%e expr] in
                     e]
               else None),
              if do_decode then
                Some
                  [%expr
                    let _, d = [%e expr] in
                    d]
              else None )
        | Error s -> fail ptyp_loc s
      in
      match List.length typeArgs = 0 with
      | true -> (encode, decode)
      | false -> parameterize_value_codecs typeArgs encode decode generator_settings)
  | _ -> fail ptyp_loc "This syntax is not yet handled by spice"

let generate_codecs generator_settings core_type =
  generate_codecs_for Optional_context generator_settings core_type

let generate_value_codecs generator_settings core_type =
  generate_codecs_for Value_context generator_settings core_type
