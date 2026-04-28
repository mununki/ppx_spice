open Ppxlib
open Parsetree
open Ast_helper
open Utils

type parsed_decl = {
  name : string;
  alias : expression;
  has_attr_as : bool;
  constr_decl : Parsetree.constructor_declaration;
}

let generate_encoder_case generator_settings unboxed has_attr_as
    { name; alias = constructor_expr; constr_decl = { pcd_args; pcd_loc } } =
  match pcd_args with
  | Pcstr_tuple args ->
      let json_expr =
        match constructor_expr with
        | { pexp_desc = Pexp_constant const; pexp_loc } -> (
            match const with
            | Pconst_string _ -> [%expr JSON.String [%e constructor_expr]]
            | Pconst_float _ -> [%expr JSON.Number [%e constructor_expr]]
            | Pconst_integer _ -> [%expr JSON.Number [%e constructor_expr]]
            | _ -> fail pexp_loc "cannot find a name??!")
        | { pexp_loc } -> fail pexp_loc "cannot find a name???"
      in
      let lhs_vars =
        match args with
        | [] -> None
        | [ _ ] -> Some (Pat.var (mknoloc "v0"))
        | _ ->
            args
            |> List.mapi (fun i _ ->
                   mkloc ("v" ^ string_of_int i) pcd_loc |> Pat.var)
            |> Pat.tuple
            |> fun v -> Some v
      in
      let rhs_list =
        args
        |> List.map (Codecs.generate_value_codecs generator_settings)
        |> List.map (fun (encoder, _) -> Option.get encoder)
        |> List.mapi (fun i e ->
               Exp.apply ~loc:pcd_loc e
                 [ (Asttypes.Nolabel, make_ident_expr ("v" ^ string_of_int i)) ])
        |> List.append [ json_expr ]
      in

      {
        pc_lhs = Pat.construct (lid name) lhs_vars;
        pc_guard = None;
        pc_rhs =
          (if unboxed then List.tl rhs_list |> List.hd
           else if has_attr_as then json_expr
           else [%expr JSON.Array [%e rhs_list |> Exp.array]]);
      }
  | Pcstr_record _ -> fail pcd_loc "This syntax is not yet implemented by spice"

let generate_decode_success_case num_args constructor_name =
  {
    pc_lhs =
      Array.init num_args (fun i ->
          mknoloc ("v" ^ string_of_int i) |> Pat.var |> fun p ->
          [%pat? Ok [%p p]])
      |> Array.to_list
      |> tuple_or_singleton Pat.tuple;
    pc_guard = None;
    pc_rhs =
      ( Array.init num_args (fun i -> make_ident_expr ("v" ^ string_of_int i))
      |> Array.to_list
      |> tuple_or_singleton Exp.tuple
      |> fun v ->
        Some v |> Exp.construct (lid constructor_name) |> fun e ->
        [%expr Ok [%e e]] );
  }

let generate_arg_decoder generator_settings args constructor_name =
  let num_args = List.length args in
  args
  (* has_type_offset because index 0 is the constructor *)
  |> List.mapi (Decode_cases.generate_error_case ~has_type_offset:true num_args)
  |> List.append [ generate_decode_success_case num_args constructor_name ]
  |> Exp.match_
       (args
       |> List.map (Codecs.generate_value_codecs generator_settings)
       |> List.mapi (fun i (_, decoder) ->
              Exp.apply (Option.get decoder)
                [
                  ( Asttypes.Nolabel,
                    (* +1 because index 0 is the constructor *)
                    let idx =
                      Pconst_integer (string_of_int (i + 1), None)
                      |> Exp.constant
                    in
                    [%expr Array.getUnsafe json_arr [%e idx]] );
                ])
       |> tuple_or_singleton Exp.tuple)

let generate_decoder_case generator_settings
    { pcd_name = { txt = name }; pcd_args; pcd_loc } =
  match pcd_args with
  | Pcstr_tuple args ->
      let arg_len =
        Pconst_integer (string_of_int (List.length args + 1), None)
        |> Exp.constant
      in
      let decoded =
        match args with
        | [] ->
            let ident = lid name in
            [%expr Ok [%e Exp.construct ident None]]
        | _ -> generate_arg_decoder generator_settings args name
      in

      {
        pc_lhs =
          ( Pconst_string (name, Location.none, None) |> Pat.constant |> fun v ->
            Some v |> Pat.construct (lid "JSON.String") );
        pc_guard = None;
        pc_rhs =
          [%expr
            if Array.length json_arr <> [%e arg_len] then
              Spice.error "Invalid number of arguments to variant constructor" v
            else [%e decoded]];
      }
  | Pcstr_record _ -> fail pcd_loc "This syntax is not yet implemented by spice"

let generate_decoder_case_attr ~is_string generator_settings
    { name; alias; constr_decl = { pcd_args; pcd_loc } } =
  match pcd_args with
  | Pcstr_tuple args -> (
      let const =
        if is_string then get_string_from_expression alias
        else get_float_from_expression alias
      in
      let decoded =
        match args with
        | [] ->
            let ident = lid name in
            [%expr Ok [%e Exp.construct ident None]]
        | _ -> generate_arg_decoder generator_settings args name
      in

      match const with
      | Some const ->
          let if' =
            Exp.apply (make_ident_expr "=")
              [
                (Asttypes.Nolabel, Exp.constant const);
                (Asttypes.Nolabel, [%expr str_or_num]);
              ]
          in
          let then' = [%expr [%e decoded]] in

          Some (if', then')
      | None -> None)
  | Pcstr_record _ -> fail pcd_loc "This syntax is not yet implemented by spice"

let generate_unboxed_decode generator_settings
    { pcd_name = { txt = name }; pcd_args; pcd_loc } =
  match pcd_args with
  | Pcstr_tuple args -> (
      match args with
      | [ a ] -> (
          let _, d = Codecs.generate_value_codecs generator_settings a in
          match d with
          | Some d ->
              let constructor = Exp.construct (lid name) (Some [%expr v]) in
              let inline_fun_expr =
                Utils.expr_func ~arity:1 [%expr fun v -> [%e constructor]]
              in

              Some
                (Utils.expr_func ~arity:1
                   [%expr fun v -> Result.map ([%e d] v) [%e inline_fun_expr]])
          | None -> None)
      | _ -> fail pcd_loc "Expected exactly one type argument")
  | Pcstr_record _ -> fail pcd_loc "This syntax is not yet implemented by spice"

let parse_decl _generator_settings
    ({ pcd_name = { txt }; pcd_loc; pcd_attributes } as constr_decl) =
  let alias, has_attr_as =
    match get_attribute_by_name pcd_attributes "spice.as" with
    | Ok (Some attribute) -> (get_expression_from_payload attribute, true)
    | Ok None ->
        (Exp.constant (Pconst_string (txt, Location.none, Some "*j")), false)
    | Error s -> (fail pcd_loc s, false)
  in

  { name = txt; alias; has_attr_as; constr_decl }

let validate_spice_as_payload unboxed parsed_decls =
  if not unboxed then
    parsed_decls
    |> List.iter
         (fun { has_attr_as; constr_decl = { pcd_args; pcd_loc }; _ } ->
           match (has_attr_as, pcd_args) with
           | true, Pcstr_tuple (_ :: _) ->
               fail pcd_loc
                 "@spice.as is only supported on constructors without payload; \
                  use the default tagged array encoding or @unboxed for \
                  single-payload variants"
           | _ -> ())

let generate_codecs ({ do_encode; do_decode } as generator_settings)
    constr_decls unboxed =
  let parsed_decls = List.map (parse_decl generator_settings) constr_decls in
  let count_has_attr =
    parsed_decls |> List.filter (fun v -> v.has_attr_as) |> List.length
  in
  let has_attr_as =
    if count_has_attr > 0 then
      if count_has_attr = List.length parsed_decls then true
      else failwith "Partial @spice.as usage is not allowed"
    else false
  in
  validate_spice_as_payload unboxed parsed_decls;

  let encoder =
    if do_encode then
      let match_expr =
        parsed_decls
        |> List.map
             (generate_encoder_case generator_settings unboxed has_attr_as)
        |> Exp.match_ [%expr v]
      in
      Some
        (Exp.constraint_ match_expr Utils.ctyp_json_t
        |> Exp.fun_ Asttypes.Nolabel None [%pat? v]
        |> Utils.expr_func ~arity:1)
    else None
  in

  let decoder =
    match not do_decode with
    | true -> None
    | false ->
        if unboxed then
          generate_unboxed_decode generator_settings (List.hd constr_decls)
        else if has_attr_as then
          let rec make_ifthenelse cases =
            match cases with
            | [] -> [%expr Spice.error "Not matched" v]
            | hd :: tl ->
                let if_, then_ = hd in
                Exp.ifthenelse if_ then_ (Some (make_ifthenelse tl))
          in

          let decoder_switch =
            List.filter_map
              (generate_decoder_case_attr ~is_string:true generator_settings)
              parsed_decls
            |> make_ifthenelse
          in

          let decoder_switch_num =
            List.filter_map
              (generate_decoder_case_attr ~is_string:false generator_settings)
              parsed_decls
            |> make_ifthenelse
          in

          Some
            (Utils.expr_func ~arity:1
               [%expr
                 fun v ->
                   match (v : JSON.t) with
                   | JSON.String str_or_num -> [%e decoder_switch]
                   | JSON.Number str_or_num -> [%e decoder_switch_num]
                   | _ -> Spice.error "Not a JSONString" v])
        else
          let decoder_default_case =
            {
              pc_lhs = [%pat? _];
              pc_guard = None;
              pc_rhs =
                [%expr
                  Spice.error "Invalid variant constructor"
                    (Array.getUnsafe json_arr 0)];
            }
          in

          let decoder_switch =
            constr_decls |> List.map (generate_decoder_case generator_settings)
            |> fun l ->
            l @ [ decoder_default_case ]
            |> Exp.match_ [%expr Array.getUnsafe json_arr 0]
          in

          Some
            (Utils.expr_func ~arity:1
               [%expr
                 fun v ->
                   match (v : JSON.t) with
                   | JSON.Array [||] ->
                       Spice.error "Expected variant, found empty array" v
                   | JSON.Array json_arr -> [%e decoder_switch]
                   | _ -> Spice.error "Not a variant" v])
  in

  (encoder, decoder)
