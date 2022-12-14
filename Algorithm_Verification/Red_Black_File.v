(**Parameter int : Type.
(**Extract Inlined Constant int => "int".*)

Parameter Abs : int -> Z.
Axiom Abs_inj: forall (n m : int), Abs n = Abs m -> n = m.

Parameter ltb: int -> int -> bool.
Extract Inlined Constant ltb => "( < )".
Axiom ltb_lt : forall (n m : int), ltb n m = true <-> Abs n < Abs m.
Parameter leb: int \u2192 int \u2192 bool.
Extract Inlined Constant leb \u21d2 "( <= )".
Axiom leb_le : \u2200 (n m : int), leb n m = true \u2194 Abs n \u2264 Abs m.
**)

From Coq Require Import String.
From Coq Require Export Arith.
From Coq Require Export Lia.

Notation  "a >=? b" := (Nat.leb b a) (at level 70) : nat_scope.
Notation  "a >? b"  := (Nat.ltb b a) (at level 70) : nat_scope.


Definition key := nat.

Inductive color := Red | Black.

Inductive tree (V : Type) : Type :=
| E : tree V
| T : color -> tree V -> key -> V -> tree V -> tree V.

Arguments E {V}.
Arguments T {V}.

Definition empty_tree (V : Type) : tree V :=
  E.

Fixpoint lookup {V : Type} (d : V) (x: key) (t : tree V) : V :=
  match t with
  | E => d
  | T _ tl k v tr => if k >? x then lookup d x tl
                    else if x >? k then lookup d x tr
                         else v
  end.

Definition balance
           {V : Type} (c : color) (t1 : tree V) (k : key) (vk : V)
           (t2 : tree V) : tree V :=
  match c with
  | Red => T Red t1 k vk t2
  | _ => match t1 with
        | T Red (T Red a x vx b) y vy c =>
            T Red (T Black a x vx b) y vy (T Black c k vk t2)
        | T Red a x vx (T Red b y vy c) =>
            T Red (T Black a x vx b) y vy (T Black c k vk t2)
        | _ => match t2 with
              | T Red (T Red b y vy c) z vz d =>
                  T Red (T Black t1 k vk b) y vy (T Black c z vz d)
              | T Red b y vy (T Red c z vz d) =>
                  T Red (T Black t1 k vk b) y vy (T Black c z vz d)
              | _ => T Black t1 k vk t2
              end
        end
  end.

Fixpoint ins {V : Type} (x : key) (vx : V) (t : tree V) : tree V :=
  match t with
  | E => T Red E x vx E
  | T c a y vy b => if y >? x then balance c (ins x vx a) y vy b
                   else if x >? y then balance c a y vy (ins x vx b)
                        else T c a x vx b
  end.

Definition make_black {V : Type} (t : tree V) : tree V :=
  match t with
  | E => E
  | T _ a x vx b => T Black a x vx b
  end.

Definition insert {V : Type} (x : key) (vx : V) (t : tree V) :=
  make_black (ins x vx t).

Fixpoint elements_aux {V : Type} (t : tree V) (acc: list (key * V))
  : list (key * V) :=
  match t with
  | E => acc
  | T _ l k v r => elements_aux l ((k, v) :: elements_aux r acc)
  end.

Notation "[ ]" := nil.

Definition elements {V : Type} (t : tree V) : list (key * V) :=
  elements_aux t [].

Lemma ins_not_E : forall (V : Type) (x : key) (vx : V) (t : tree V),
    not (ins x vx t = E).
Proof.
   intros. destruct t; simpl.
  - discriminate.
  - unfold balance.
    repeat
      match goal with
      | |- (if ?x then _ else _) <> _ => destruct x
      | |- match ?c with Red => _ | Black => _ end <> _=> destruct c
      | |- match ?t with E => _ | T _ _ _ _ _ => _ end <> _=> destruct t
      | |- T _ _ _ _ _ <> E => discriminate
      end.
Qed.

Fixpoint ForallT {V : Type} (P: nat -> V -> Prop) (t : tree V) : Prop :=
  match t with
  | E => True
  | T c l k v r => P k v /\ ForallT P l /\ ForallT P r
  end.

Lemma balanceP : forall (V : Type) (P : key -> V -> Prop) (c : color) (l r : tree V)
                   (k : key) (v : V),
    ForallT P l ->
    ForallT P r ->
    P k v ->
    ForallT P (balance c l k v r).
Proof.
  intros. unfold balance.
    repeat
      match goal with
      | |- match ?c with Red => _ | Black => _ end => destruct c
      | |- match ?l with E => _ | T _ _ _ _ _ => _ end => destruct l
      | |- T _ _ _ _ _ => repeat split
      | |- P k v => auto
      | |- ForallT _ _ => auto
      end.
  Admitted. 

Inductive reflect (P : Prop) : bool -> Set :=
  | reflectT :   P -> reflect P true
  | reflectF : ~ P -> reflect P false.

Theorem iff_reflect : forall P b, (P <-> b = true) -> reflect P b.
Proof.
  intros P b H. destruct b. 
  - inversion H. apply reflectT. simpl in H1. rewrite H. reflexivity. 
  - inversion H. apply reflectF. unfold not. rewrite H. intros. discriminate H2. 
Qed. 

Theorem reflect_iff : forall P b, reflect P b -> (P <-> b = true).
Proof.
  intros P b H. split. 
  - inversion H. 
    * intros. reflexivity. 
    * intros. unfold not in H0. apply H0 in H2. contradiction. 
  - intros. subst. inversion H. apply H0. 
Qed. 

Lemma eqb_reflect : forall x y, reflect (x = y) (x =? y).
Proof.
  intros. apply iff_reflect. symmetry. apply Nat.eqb_eq. 
Qed. 

Lemma ltb_reflect : forall x y, reflect (x < y) (x <? y).
Proof.
  intros. apply iff_reflect. symmetry. apply Nat.ltb_lt.
Qed.

Lemma leb_reflect : forall x y, reflect (x <= y) (x <=? y).
Proof.
  intros. apply iff_reflect. symmetry. apply Nat.leb_le.
Qed. 

Hint Resolve ltb_reflect leb_reflect eqb_reflect : bdestruct.

Ltac bdestruct X :=
  let H := fresh in let e := fresh "e" in
   evar (e: Prop);
   assert (H: reflect e X); subst e;
    [eauto with bdestruct
    | destruct H as [H|H];
       [ | try first [apply not_lt in H | apply not_le in H]]].


Lemma insP : forall (V : Type) (P : key -> V -> Prop) (t : tree V) (k : key) (v : V),
    ForallT P t ->
    P k v ->
    ForallT P (ins k v t).
Proof.
  intros. induction t. 
    - simpl. repeat split. 
      * apply H0. 
    - simpl. bdestruct (k0 >? k). 
      * apply balanceP. 
        ++ inversion H. destruct H3. apply IHt1 in H3. apply H3. 
        ++ inversion H. destruct H3. apply H4. 
        ++ inversion H. apply H2.
      * bdestruct (k >? k0). 
        ++ apply balanceP. 
          ** inversion H. destruct H4. apply H4. 
          ** inversion H. destruct H4. apply IHt2 in H5. apply H5. 
          ** inversion H. apply H3. 
        ++ assert (k0 = k). lia. simpl. repeat split. 
          ** apply H0. 
          ** inversion H. destruct H5. apply H5. 
          ** inversion H. destruct H5. apply H6. 
Qed. 

Inductive BST {V : Type} : tree V -> Prop :=
| ST_E : BST E
| ST_T : forall (c : color) (l : tree V) (k : key) (v : V) (r : tree V),
    ForallT (fun k' _ => k'< k) l ->
    ForallT (fun k' _ => k'> k) r ->
    BST l ->
    BST r ->
    BST (T c l k v r).

Lemma ForallT_imp : forall (V : Type) (P Q : nat -> V -> Prop) t,
    ForallT P t ->
    (forall k v, P k v -> Q k v) ->
    ForallT Q t.
Proof.
  induction t; intros.
  - auto.
  - destruct H as [? [? ?]]. repeat split; auto.
Qed.
Lemma ForallT_greater : forall (V : Type) (t : tree V) (k k0 : key),
    ForallT (fun k' _ => k' > k) t ->
    k > k0 ->
    ForallT (fun k' _ => k' > k0) t.
Proof.
  intros. eapply ForallT_imp; eauto.
  intros. simpl in H1. lia.
Qed.
Lemma ForallT_less : forall (V : Type) (t : tree V) (k k0 : key),
    ForallT (fun k' _ => k' < k) t ->
    k < k0 ->
    ForallT (fun k' _ => k' < k0) t.
Proof.
  intros; eapply ForallT_imp; eauto.
  intros. simpl in H1. lia.
Qed.

Lemma balance_BST: forall (V : Type) (c : color) (l : tree V) (k : key)
                     (v : V) (r : tree V),
    ForallT (fun k' _ => k' < k) l ->
    ForallT (fun k' _ => k' > k) r ->
    BST l ->
    BST r ->
    BST (balance c l k v r).
Proof.
  intros. unfold balance.
  repeat
    match goal with
    | H: ForallT _ (T _ _ _ _ _) |- _ => destruct H as [? [? ?] ]
    | H: BST (T _ _ _ _ _) |- _ => inversion H; clear H; subst
    | |- BST (T _ _ _ _ _) => constructor
    | |- BST (match ?c with Red => _ | Black => _ end) => destruct c
    | |- BST (match ?t with E => _ | T _ _ _ _ _ => _ end) => destruct t
    | |- ForallT _ (T _ _ _ _ _) => repeat split
    end;
    auto; try lia.
  all: try eapply ForallT_greater; try eapply ForallT_less; eauto; try lia.
Qed. 


Lemma ins_BST : forall (V : Type) (t : tree V) (k : key) (v : V),
    BST t ->
    BST (ins k v t).
Proof.
  intros. induction t. 
  - simpl. apply ST_T. 
    * reflexivity. 
    * reflexivity. 
    * apply H. 
    * apply ST_E. 
  - simpl. bdestruct (k0 >? k). 
    * apply balance_BST. 
      ** apply insP. 
        + inversion H. apply H5. 
        + apply H0. 
      ** inversion H. apply H7. 
      ** inversion H. apply IHt1 in H8. apply H8. 
      ** inversion H. apply H9. 
    * bdestruct (k >? k0). 
      ** apply balance_BST. 
         + inversion H. apply H6. 
         + apply insP. inversion H. 
           ++ apply H8. 
           ++ apply H1. 
         + inversion H. apply H9. 
         + inversion H. apply IHt2 in H10. apply H10.
      ** apply ST_T. inversion H. assert (k = k0). lia. 
          + rewrite H11. apply H6. 
          + inversion H. assert (k = k0). lia. rewrite H11. apply H8. 
          + inversion H. apply H9. 
          + inversion H. apply H10. 
Qed. 

Theorem helper : forall (V: Type) (t : tree V) (v : V) (k : key),
    BST t -> 
    BST (make_black t).
  intros. unfold make_black. induction t. 
    - apply ST_E. 
    - apply ST_T. inversion H. 
      * apply H4. 
      * inversion H. apply H6. 
      * inversion H. apply H7. 
      * inversion H. apply H8. 
Qed. 

Theorem insert_BST : forall (V : Type) (t : tree V) (v : V) (k : key),
    BST t ->
    BST (insert k v t).
Proof.
  intros. unfold insert. apply helper. 
    - apply v. 
    - apply k. 
      - apply ins_BST. apply H. 
Qed. 

Lemma balance_lookup: forall (V : Type) (d : V) (c : color) (k k' : key) (v : V)
                        (l r : tree V),
    BST l ->
    BST r ->
    ForallT (fun k' _ => k' < k) l ->
    ForallT (fun k' _ => k' > k) r ->
    lookup d k' (balance c l k v r) =
      if k' <? k
      then lookup d k' l
      else if k' >? k
           then lookup d k' r
           else v.
Proof.
  (* FILL IN HERE *) Admitted.

Lemma lookup_ins_eq: forall (V : Type) (d : V) (t : tree V) (k : key) (v : V),
    BST t ->
    lookup d k (ins k v t) = v.
Proof.

  intros. induction H. 
  - simpl. bdestruct (k >? k). 
    * lia. 
    * reflexivity. 
  - simpl. bdestruct (k0 >? k). 
    * rewrite balance_lookup. 
      + bdestruct (k0 >? k). 
        ++ apply IHBST1. 
        ++ lia. 
      + apply ins_BST. apply H1. 
      + apply H2. 
      + apply insP. 
        ++ apply H. 
        ++ lia. 
      + apply H0. 
    * bdestruct (k >? k0). 
      + rewrite balance_lookup. 
        ++ bdestruct (k0 >? k). lia. bdestruct (k >? k0). apply IHBST2. lia. 
        ++ apply H1. 
        ++ apply ins_BST. apply H2. 
        ++ apply H. 
        ++ apply insP. apply H0. apply H4. 
      + assert (k = k0). lia. simpl. bdestruct (k >? k). 
        ++ lia. 
        ++ reflexivity. 
Qed. 

Theorem lookup_ins_neq: forall (V : Type) (d : V) (t : tree V) (k k' : key)
                          (v : V),
    BST t -> 
    not (k = k') ->
    lookup d k' (ins k v t) = lookup d k' t.
Proof.
  intros. induction H. 
  - simpl. bdestruct (k >? k'). reflexivity. bdestruct (k' >? k). reflexivity. lia. 
  - simpl. bdestruct (k0 >? k). 
    * rewrite balance_lookup. 
      ** bdestruct (k0 >? k'). 
        + apply IHBST1. 
        + bdestruct (k' >? k0). reflexivity. reflexivity. 
      ** apply ins_BST. apply H2. 
      ** apply H3. 
      ** apply insP. apply H. apply H4. 
      ** apply H1.
     * bdestruct (k >? k0). 
      ** rewrite balance_lookup. 
        + bdestruct (k0 >? k'). reflexivity. 
        bdestruct (k' >? k0). apply IHBST2. reflexivity. 
        + apply H2. 
        + apply ins_BST. apply H3. 
        + apply H. 
        + apply insP. apply H1. apply H5. 
      ** bdestruct (k0 >? k'). 
        + simpl. bdestruct (k >? k'). reflexivity. bdestruct (k' >? k). lia. lia. 
        + bdestruct (k' >? k0). 
          ++ simpl. bdestruct (k >? k'). lia. bdestruct (k' >? k). reflexivity. 
          lia. 
          ++ simpl. bdestruct (k >? k'). lia. bdestruct (k' >? k). lia. lia. 
Qed. 



Theorem helper_lookup : forall (V: Type) (d: V) (t : tree V) (k : key) (v : V) ,
    lookup d k t = v -> 
    lookup d k (make_black t) = v.
Proof.
  intros. unfold make_black. induction t. 
   - apply H. 
   - apply H. 
Qed. 

Theorem helper_lookup2 : forall (V: Type) (d: V) (t2 : tree V) (t : tree V) (k : key) (v : V) ,
    lookup d k t = lookup d k t2  -> 
    lookup d k (make_black t) = lookup d k t2.
Proof.
  intros. unfold make_black. induction t. 
   - apply H. 
   - apply H. 
Qed. 

Theorem lookup_insert_eq : forall (V : Type) (d : V) (t : tree V) (k : key)
                             (v : V),
    BST t ->
    lookup d k (insert k v t) = v.
Proof.
  intros. unfold insert. rewrite helper_lookup with (V) (d) ((ins k v t)) (k) (v). 
  - reflexivity. 
  - apply lookup_ins_eq. apply H. 
Qed. 

Theorem lookup_insert_neq: forall (V : Type) (d : V) (t : tree V) (k k' : key)
                             (v : V),
    BST t ->
    not (k = k') ->
    lookup d k' (insert k v t) = lookup d k' t.
Proof.
  intros. unfold insert. apply helper_lookup2. 
  - apply v. 
  - apply lookup_ins_neq. 
    * apply H. 
    * apply H0. 
Qed. 

Inductive RB {V : Type} : tree V -> color -> nat -> Prop :=
| RB_leaf: forall (c : color), RB E c 0
| RB_r: forall (l r : tree V) (k : key) (v : V) (n : nat),
    RB l Red n ->
    RB r Red n ->
    RB (T Red l k v r) Black n
| RB_b: forall (c : color) (l r : tree V) (k : key) (v : V) (n : nat),
    RB l Black n ->
    RB r Black n ->
    RB (T Black l k v r) c (S n).

Lemma RB_blacken_parent : forall (V : Type) (t : tree V) (n : nat),
    RB t Red n -> RB t Black n.
Proof.
  intros. induction H. 
  - apply RB_leaf. 
  - apply RB_r. 
   * apply H. 
   * apply H0. 
  - apply RB_b. 
   * apply H. 
   * apply H0. 
Qed. 

Inductive NearlyRB {V : Type} : tree V -> nat -> Prop :=
| NearlyRB_r : forall (l r : tree V) (k : key) (v : V) (n : nat),
    RB l Black n ->
    RB r Black n ->
    NearlyRB (T Red l k v r) n
| NearlyRB_b : forall (l r : tree V) (k : key) (v : V) (n : nat),
    RB l Black n ->
    RB r Black n ->
    NearlyRB (T Black l k v r) (S n).

Ltac prove_RB := admit.
Lemma ins_RB : forall (V : Type) (k : key) (v : V) (t : tree V) (n : nat),
    (RB t Black n -> NearlyRB (ins k v t) n) /\
      (RB t Red n -> RB (ins k v t) Black n).
Proof.
  induction t; split; intros; inversion H; repeat constructor; simpl.
  - (* Instantiate the inductive hypotheses. *)
    specialize (IHt1 n). specialize (IHt2 n).
    (* Derive what propositional facts we can from the hypotheses. *)
    intuition.
    (* Get rid of some extraneous hypotheses. *)
    clear H H1.
    (* Finish with automation. *)
    prove_RB.
  - specialize (IHt1 n0). specialize (IHt2 n0). intuition.
    clear H0 H2.
    prove_RB.
  - specialize (IHt1 n0). specialize (IHt2 n0). intuition.
    clear H0 H2.
    prove_RB.
    (* FILL IN HERE *) Admitted.

Lemma RB_blacken_root : forall (V : Type) (t : tree V) (n : nat),
    RB t Black n ->
    exists (n' : nat), RB (make_black t) Red n'.
Proof.
   intros. induction H. 
    - simpl. exists 0. apply RB_leaf. 
    - simpl. exists (S n). apply RB_b. 
      * apply RB_blacken_parent. apply H. 
      * apply RB_blacken_parent. apply H0. 
    - simpl. exists (S n). apply RB_b. 
      * apply H. 
      * apply H0. 
Qed. 

Lemma insert_RB : forall (V : Type) (t : tree V) (k : key) (v : V) (n : nat),
    RB t Red n -> 
    exists (n' : nat), RB (insert k v t) Red n'.
Proof.
  intros. unfold insert. apply RB_blacken_root with n. apply ins_RB. apply H. 
Qed. 






