(* This file is part of the Catala compiler, a specification language for tax and social benefits
   computation rules. Copyright (C) 2022 Inria, contributor: Aymeric Fromherz
   <aymeric.fromherz@inria.fr>

   Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
   in compliance with the License. You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software distributed under the License
   is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
   or implied. See the License for the specific language governing permissions and limitations under
   the License. *)

open Utils
open Dcalc
open Ast
open Z3

type context = { ctx_z3 : Z3.context; ctx_decl : decl_ctx; ctx_var : typ Pos.marked VarMap.t }

(** [translate_typ_lit] returns the Z3 sort corresponding to the Catala literal type [t] **)
let translate_typ_lit (ctx : context) (t : typ_lit) : Sort.sort =
  match t with
  | TBool -> Boolean.mk_sort ctx.ctx_z3
  | TUnit -> failwith "[Z3 encoding] TUnit type not supported"
  | TInt -> Arithmetic.Integer.mk_sort ctx.ctx_z3
  | TRat -> failwith "[Z3 encoding] TRat type not supported"
  | TMoney -> failwith "[Z3 encoding] TMoney type not supported"
  | TDate -> failwith "[Z3 encoding] TDate type not supported"
  | TDuration -> failwith "[Z3 encoding] TDuration type not supported"

(** [translate_typ] returns the Z3 sort correponding to the Catala type [t] **)
let translate_typ (ctx : context) (t : typ) : Sort.sort =
  match t with
  | TLit t -> translate_typ_lit ctx t
  | TTuple _ -> failwith "[Z3 encoding] TTuple type not supported"
  | TEnum _ -> failwith "[Z3 encoding] TEnum type not supported"
  | TArrow _ -> failwith "[Z3 encoding] TArrow type not supported"
  | TArray _ -> failwith "[Z3 encoding] TArray type not supported"
  | TAny -> failwith "[Z3 encoding] TAny type not supported"

(** [translate_lit] returns the Z3 expression as a literal corresponding to [lit] **)
let translate_lit (ctx : context) (l : lit) : Expr.expr =
  match l with
  | LBool b -> if b then Boolean.mk_true ctx.ctx_z3 else Boolean.mk_false ctx.ctx_z3
  | LEmptyError -> failwith "[Z3 encoding] LEmptyError literals not supported"
  | LInt n -> Arithmetic.Integer.mk_numeral_i ctx.ctx_z3 (Runtime.integer_to_int n)
  | LRat _ -> failwith "[Z3 encoding] LRat literals not supported"
  | LMoney _ -> failwith "[Z3 encoding] LMoney literals not supported"
  | LUnit -> failwith "[Z3 encoding] LUnit literals not supported"
  | LDate _ -> failwith "[Z3 encoding] LDate literals not supported"
  | LDuration _ -> failwith "[Z3 encoding] LDuration literals not supported"

(** [translate_op] returns the Z3 expression corresponding to the application of [op] to the
    arguments [args] **)
let rec translate_op (ctx : context) (op : operator) (args : expr Pos.marked list) : Expr.expr =
  match op with
  | Ternop _top ->
      let _e1, _e2, _e3 =
        match args with
        | [ e1; e2; e3 ] -> (e1, e2, e3)
        | _ ->
            failwith
              (Format.asprintf "[Z3 encoding] Ill-formed ternary operator application: %a"
                 (Print.format_expr ctx.ctx_decl)
                 (EApp ((EOp op, Pos.no_pos), args), Pos.no_pos))
      in

      failwith "[Z3 encoding] ternary operator application not supported"
  | Binop bop -> (
      let e1, e2 =
        match args with
        | [ e1; e2 ] -> (e1, e2)
        | _ ->
            failwith
              (Format.asprintf "[Z3 encoding] Ill-formed binary operator application: %a"
                 (Print.format_expr ctx.ctx_decl)
                 (EApp ((EOp op, Pos.no_pos), args), Pos.no_pos))
      in

      match bop with
      | And -> Boolean.mk_and ctx.ctx_z3 [ translate_expr ctx e1; translate_expr ctx e2 ]
      | Or -> Boolean.mk_or ctx.ctx_z3 [ translate_expr ctx e1; translate_expr ctx e2 ]
      | Xor -> Boolean.mk_xor ctx.ctx_z3 (translate_expr ctx e1) (translate_expr ctx e2)
      | Add KInt -> Arithmetic.mk_add ctx.ctx_z3 [ translate_expr ctx e1; translate_expr ctx e2 ]
      | Add _ -> failwith "[Z3 encoding] application of non-integer binary operator Add not supported"
      | Sub KInt -> Arithmetic.mk_sub ctx.ctx_z3 [ translate_expr ctx e1; translate_expr ctx e2 ]
      | Sub _ -> failwith "[Z3 encoding] application of non-integer binary operator Sub not supported"
      | Mult KInt -> Arithmetic.mk_mul ctx.ctx_z3 [ translate_expr ctx e1; translate_expr ctx e2 ]
      | Mult _ -> failwith "[Z3 encoding] application of non-integer binary operator Mult not supported"
      | Div KInt -> Arithmetic.mk_div ctx.ctx_z3 (translate_expr ctx e1) (translate_expr ctx e2)
      | Div _ -> failwith "[Z3 encoding] application of non-integer binary operator Div not supported"
      | Lt KInt ->  Arithmetic.mk_lt ctx.ctx_z3 (translate_expr ctx e1) (translate_expr ctx e2)
      | Lt _ -> failwith "[Z3 encoding] application of non-integer binary operator Lt not supported"
      | Lte _ -> failwith "[Z3 encoding] application of binary operator Lte not supported"
      | Gt KInt -> Arithmetic.mk_gt ctx.ctx_z3 (translate_expr ctx e1) (translate_expr ctx e2)
      | Gt _ -> failwith "[Z3 encoding] application of non-integer binary operator Gt not supported"
      | Gte KInt -> Arithmetic.mk_ge ctx.ctx_z3 (translate_expr ctx e1) (translate_expr ctx e2)
      | Gte _ ->
          failwith "[Z3 encoding] application of non-integer binary operator Gte not supported"
      | Eq -> Boolean.mk_eq ctx.ctx_z3 (translate_expr ctx e1) (translate_expr ctx e2)
      | Neq -> Boolean.mk_not ctx.ctx_z3 (Boolean.mk_eq ctx.ctx_z3 (translate_expr ctx e1) (translate_expr ctx e2))
      | Map -> failwith "[Z3 encoding] application of binary operator Map not supported"
      | Concat -> failwith "[Z3 encoding] application of binary operator Concat not supported"
      | Filter -> failwith "[Z3 encoding] application of binary operator Filter not supported")
  | Unop uop -> (
      let e1 =
        match args with
        | [ e1 ] -> e1
        (* TODO: Print term for error message *)
        | _ -> failwith "[Z3 encoding] Ill-formed unary operator application"
      in

      match uop with
      | Not -> Boolean.mk_not ctx.ctx_z3 (translate_expr ctx e1)
      | Minus _ -> failwith "[Z3 encoding] application of unary operator Minus not supported"
      (* Omitting the log from the VC *)
      | Log _ -> translate_expr ctx e1
      | Length -> failwith "[Z3 encoding] application of unary operator Length not supported"
      | IntToRat -> failwith "[Z3 encoding] application of unary operator IntToRat not supported"
      | GetDay -> failwith "[Z3 encoding] application of unary operator GetDay not supported"
      | GetMonth -> failwith "[Z3 encoding] application of unary operator GetMonth not supported"
      | GetYear -> failwith "[Z3 encoding] application of unary operator GetYear not supported")

(** [translate_expr] translate the expression [vc] to its corresponding Z3 expression **)
and translate_expr (ctx : context) (vc : expr Pos.marked) : Expr.expr =
  match Pos.unmark vc with
  | EVar v ->
      let t = VarMap.find (Pos.unmark v) ctx.ctx_var in
      let v = Pos.unmark v in
      let name = Format.asprintf "%s_%d" (Bindlib.name_of v) (Bindlib.uid_of v) in
      Expr.mk_const_s ctx.ctx_z3 name (translate_typ ctx (Pos.unmark t))
  | ETuple _ -> failwith "[Z3 encoding] ETuple unsupported"
  | ETupleAccess _ -> failwith "[Z3 encoding] ETupleAccess unsupported"
  | EInj _ -> failwith "[Z3 encoding] EInj unsupported"
  | EMatch _ -> failwith "[Z3 encoding] EMatch unsupported"
  | EArray _ -> failwith "[Z3 encoding] EArray unsupported"
  | ELit l -> translate_lit ctx l
  | EAbs _ -> failwith "[Z3 encoding] EAbs unsupported"
  | EApp (head, args) -> (
      match Pos.unmark head with
      | EOp op -> translate_op ctx op args
      | _ -> failwith "[Z3 encoding] EApp of a non-operator unsupported")
  | EAssert _ -> failwith "[Z3 encoding] EAssert unsupported"
  | EOp _ -> failwith "[Z3 encoding] EOp unsupported"
  | EDefault _ -> failwith "[Z3 encoding] EDefault unsupported"
  | EIfThenElse (e_if, e_then, e_else) ->
      (* Encode this as (e_if ==> e_then) /\ (not e_if ==> e_else) *)
      let z3_if = translate_expr ctx e_if in
      Boolean.mk_and ctx.ctx_z3
        [
          Boolean.mk_implies ctx.ctx_z3 z3_if (translate_expr ctx e_then);
          Boolean.mk_implies ctx.ctx_z3 (Boolean.mk_not ctx.ctx_z3 z3_if)
            (translate_expr ctx e_else);
        ]
  | ErrorOnEmpty _ -> failwith "[Z3 encoding] ErrorOnEmpty unsupported"

type vc_encoding_result = Success of Expr.expr | Fail of string

(** [solve_vc] is the main entry point of this module. It takes a list of expressions [vcs]
    corresponding to verification conditions that must be discharged by Z3, and attempts to solve
    them **)
let solve_vc (prgm : program) (decl_ctx : decl_ctx) (vcs : Conditions.verification_condition list) :
    unit =
  Cli.debug_print (Format.asprintf "Running Z3 version %s" Version.to_string);

  let cfg = [ ("model", "true"); ("proof", "false") ] in
  let z3_ctx = mk_context cfg in

  let solver = Solver.mk_solver z3_ctx None in

  let z3_vcs =
    List.map
      (fun vc ->
        ( vc,
          try
            Success
              (translate_expr
                 { ctx_z3 = z3_ctx; ctx_decl = decl_ctx; ctx_var = variable_types prgm }
                 vc.Conditions.vc_guard)
          with Failure msg -> Fail msg ))
      vcs
  in

  List.iter
    (fun (vc, z3_vc) ->
      Cli.result_print
        (Format.asprintf
           "For this variable:\n%s\nThis verification condition was generated for %s:@\n%a"
           (Pos.retrieve_loc_text (Pos.get_position vc.Conditions.vc_guard))
           (Cli.print_with_style [ ANSITerminal.yellow ] "%s"
              (match vc.vc_kind with
              | Conditions.NoEmptyError -> "the variable definition never to return an empty error"
              | NoOverlappingExceptions -> "no two exceptions to ever overlap"))
           (Dcalc.Print.format_expr decl_ctx)
           vc.vc_guard);
      match z3_vc with
      | Success z3_vc ->
          let z3_vc_string = Expr.to_string z3_vc in
          Cli.result_print
            (Format.asprintf "The translation to Z3 is the following:@\n%s" z3_vc_string)
      | Fail msg -> Cli.error_print (Format.asprintf "The translation to Z3 failed:@\n%s" msg))
    z3_vcs;

  Solver.add solver
    (List.filter_map (fun (_, vc) -> match vc with Success e -> Some e | _ -> None) z3_vcs);

  if Solver.check solver [] = SATISFIABLE then Cli.result_print "Success: Empty unreachable"
  else
    (* TODO: Print model as error message for Catala debugging purposes *)
    Cli.error_print "Failure: Empty reachable"
