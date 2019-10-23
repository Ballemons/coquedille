Require Import Strings.String.
Require Import List. Import ListNotations.

Require Import Hask.Control.Monad.
Require Import Hask.Control.Monad.State.
Require Import Hask.Data.List.
Require Import Hask.Data.Maybe.

Require Import MetaCoq.Template.Ast.
Require Import MetaCoq.Template.AstUtils.
Require Import MetaCoq.Template.BasicAst.

Require Import Coquedille.Ast.

(* We use a default term instead of dealing with errors for now *)
Definition default_t x : Ced.Program := [Ced.CmdAssgn (Ced.AssgnTerm x (Ced.VarT x))].

(* I'm still not sure if the context should be a list Ced.Typ *)
(* Or a list Var *)
(* Because in theory the only thing the bruijn indices should refer *)
(* to would be Vars. *)
(* In fact I'm not sure if I should not be using de bruijn indices at all *)
Definition ctx := list Ced.Var.

Reserved Notation "⟦ x ⟧" (at level 0).

Definition DenoteName (n: name): Ced.Name :=
match n with
| nAnon => Ced.Anon
| nNamed c => Ced.Named c
end.

Local Open Scope string_scope.
Local Open Scope list_scope.
Fixpoint denoteTerm (t: term) {struct t}: State ctx Ced.Typ :=
let default_name := Ced.TpVar "notimpl" in
match t with
  | tProd x t1 t2 =>
    t1' <- ⟦ t1 ⟧ ;
    Γ <- get ;
    match x with
    | nAnon =>
      put ("dummy" :: Γ) ;;
      t2'  <- ⟦ t2 ⟧ ;
      pure (Ced.TpArrowT t1' t2')
    | nNamed c =>
      put (c :: Γ) ;;
          t2'  <- ⟦ t2 ⟧ ;
      pure (Ced.TpPi (Ced.Named c) t1' t2')
    end
  | tRel n =>
    Γ <- get ;
    match nth_error Γ n with
    | None => pure (Ced.TpVar "typing err")
    | Some x => pure (Ced.TpVar x)
    end
  | tApp t1 ts2 =>
    t1' <- ⟦ t1 ⟧ ;
    Γ <- get ;
    let ts2' := map (fun t => fst (⟦ t ⟧ Γ)) ts2 in
    pure (fold_left (fun p1 p2 => Ced.TpApp p1 p2) ts2' t1')
  | tInd ind univ => pure (Ced.TpVar (inductive_mind ind))
  | tSort univ => pure Ced.KdStar
  | _ => pure (Ced.TpVar "notimpl")
end
where "⟦ x ⟧" := (denoteTerm x).

Fixpoint removeBindings (t: term) (n: nat) : term :=
match n with
| O => t
| S n' =>
  match t with
  | tProd x t1 t2 => removeBindings t2 (pred n)
  | _ => t
  end
end.

Fixpoint denoteCtors (data_name : Ced.Var)
        (params: Ced.Params) (ctor: (ident * term) * nat) : Ced.Ctor  :=
let '(name, t, i) := ctor in
let v := data_name in
let paramnames := map fst params in
let clean_t := removeBindings t (length paramnames) in
let (t', _) := denoteTerm clean_t (rev (paramnames ,, v)) in
Ced.Ctr name t'.

Fixpoint denoteParams (params : context): Ced.Params :=
match params with
  | nil => []
  | cons p ps =>
    let name := decl_name p in
    let t := decl_type p in
    (match name with
     | nNamed n => [(n, fst (denoteTerm t [n]))]
     | cAnon => []
     end) ++ denoteParams ps
end.

(* Fixpoint get_ctx (gdecl: global_decl) : ctx := *)
(* match gdecl with *)
(* | ConstantDecl _ cbody => [cst_type cbody] *)
(* | InductiveDecl _ mbody => map ind_type (ind_bodies mbody) *)
(* end. *)

Instance List_Monad : Monad list :=
{ join := fun a l => fold_left (@app a) l [] }.

(* We assume that the term is well formed before calling denoteCoq *)
(* It's probably a good idea to add well formednes checker before calling it *)
(* TODO: browse metacoq library for well typed term guarantees *)
Fixpoint denoteCoq (p: program): Maybe Ced.Program :=
let (genv, t) := p in
match t with
| tInd ind univ =>
  (* let mind := inductive_mind ind in *)
  (* body <- lookup_mind_decl mind genv ; *)
  (* i_body <- head (ind_bodies body) ; *)
  (* let name := ind_name i_body in *)
  (* let ctors := ind_ctors i_body in *)
  (* let params := rev (denoteParams (ind_params body)) in *)
  (* let genv_terms := join (map get_terms genv) in *)
  (* let env : list Ced.Typ := map fst (map (fun f => denoteTerm f []) genv_terms) in *)
  (* pure [Ced.CmdData (Ced.DefData name params Ced.KdStar (fmap (denoteCtors name params) ctors))] *)
  pure [Ced.CmdAssgn (Ced.AssgnType "_" (fst (denoteTerm t [])))]
| _ => None
end.

Local Close Scope string_scope.
