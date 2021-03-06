Require Import Bool Arith List Psatz Coq.Unicode.Utf8.
Require Import Structures.OrdersEx.
Require Import Structures.Orders.
Require Import MSetAVL.

Require Import DLib.

Require MSets.MSetFacts.
Require Coq.MSets.MSetProperties.

Module N2 := PairOrderedType Nat_as_OT Nat_as_OT.
Module Triangle := PairOrderedType Nat_as_OT N2.
Module TS := MSetAVL.Make Triangle.

Module SetFacts := MSetFacts.Facts TS.
Module SetProps := MSetProperties.Properties(TS).

Lemma eq_is_eq : forall x y, Triangle.eq x y -> x = y.
Proof.
  intros [x1 [x2 x3]] [y1 [y2 y3]] H.
  compute in *.
  intuition.
  subst.
  auto.
Qed.

Notation "[ x , y , z ]" := (x,(y,z)).
Notation "{{ x , .. , y }}" := (TS.add x .. (TS.add y TS.empty) .. ).
Notation "{{}}" := TS.empty.

Definition insert csq_orig t csq_new :=
  if TS.mem t csq_orig then
    csq_new
  else
    TS.add t csq_new.

Definition step1 csq_orig t csq_new :=
  match t with
      [a,b,c] =>
      insert csq_orig [b,c,a] csq_new
  end.

Definition step4_aux a b d csq_orig t csq_new :=
  (* abd /\ bcd /\ cad -> abc *)
  match t with
      [b',c,d'] =>
      if N2.eq_dec (b,d) (b',d') then
        if TS.mem [c,a,d] csq_orig then
          insert csq_orig [a,b,c] csq_new
        else
          csq_new
      else
        csq_new
  end.

Definition step4 csq_orig t csq_new :=
  match t with
      [a,b,d] =>
      TS.fold (step4_aux a b d csq_orig) csq_orig csq_new
  end.

Definition step5_aux_aux a b c d csq_orig t csq_new :=
  match t with
      [a',b',e] =>
      if N2.eq_dec (a, b) (a' ,b') then
        if TS.mem [a,c,d] csq_orig && TS.mem [a,d,e] csq_orig then
          insert csq_orig [a,c,e] csq_new
        else
          csq_new
      else
        csq_new
  end.

Definition step5_aux a b c csq_orig t csq_new :=
  match t with
      [a',b',d] =>
      if N2.eq_dec (a, b) (a' ,b') then
        TS.fold (step5_aux_aux a b c d csq_orig) csq_orig csq_new
      else
        csq_new
  end.



Definition step5 csq_orig t csq_new :=
  match t with
      [a,b,d] =>
      TS.fold (step5_aux a b d csq_orig) csq_orig csq_new
  end.

(*** Tests step1, step4, step5  ***)
(*****
Definition test1 := {{[1,2,3],[2,3,4]}}.
Compute (TS.elements (step1 test1 [1,2,3] {{}})).

Definition test1' := {{[1,2,3],[2,3,1]}}.
Compute (TS.elements (step1 test1' [1,2,3] {{}})).

Definition test4 := {{[1,2,3],[2,4,3],[4,1,3]}}.
Compute (TS.elements (step4 test4 [1,2,3] {{}})).

Definition test5 := {{[1,2,3],[1,2,4],[1,2,5],[1,3,4],[1,4,5]}}.
Compute (TS.elements (step5 test5 [1,2,3] {{}})).
*****)

Definition step145 csq_orig :=
  let csq_new := TS.fold (step1 csq_orig) csq_orig TS.empty in
  let csq_new' := TS.fold (step4 csq_orig) csq_orig csq_new in
  let csq_new'' := TS.fold (step5 csq_orig) csq_orig csq_new' in
  if TS.is_empty csq_new'' then
    inl csq_orig
  else
    inr (TS.union csq_orig csq_new'').

Definition csq_proj (r : TS.t + TS.t) := match r with
                           | inl csq => csq
                           | inr csq => csq
                         end.

Fixpoint sat145 csq fuel {struct fuel} :=
  match fuel with
    | O => csq
    | S p =>
      match step145 csq with
        | inl csq' => csq'
        | inr csq' => sat145 csq' p
      end
  end.

Inductive Conseq : TS.t -> Triangle.t -> Prop :=
  | Id : forall ts t, TS.In t ts -> Conseq ts t
  | Rule1 : forall ts a b c, TS.In [a,b,c] ts -> Conseq ts [b,c,a]
  | Rule4 : forall ts a b c d, TS.In [a,b,d] ts -> TS.In [b,c,d] ts -> TS.In [c,a,d] ts -> Conseq ts [a,b,c]
  | Rule5 : forall ts a b c d e, TS.In [a,b,c] ts -> TS.In [a,b,d] ts -> TS.In [a,b,e] ts -> TS.In [a,c,d] ts -> TS.In [a,d,e] ts -> Conseq ts [a,c,e].

Definition Conseqs_imm ts ts' := (forall t, (TS.In t ts') -> Conseq ts t).

Definition step_correct step := forall csq_orig csq_new (t : Triangle.t),
    TS.In t csq_orig ->
    Conseqs_imm csq_orig csq_new ->
    Conseqs_imm csq_orig (step csq_orig t csq_new).

Hint Constructors Conseq.
Hint Unfold Conseqs_imm.

Lemma step1_correct : step_correct step1.
Proof.
  unfold step_correct.
  intros.
  destruct t; destruct p.
  simpl.
  unfold Conseqs_imm.
  intros.
  destruct t; destruct p.
  unfold insert in H1.
  destruct (Triangle.eq_dec [n0,n1,n] [n2,n3,n4]).
  - apply eq_is_eq in e.
    rewrite <- e in *.
    apply Rule1; auto.
  - assert (TS.In [n2, n3, n4] csq_new).
    + destruct (TS.mem [n0, n1, n] csq_orig); auto.
      apply (SetFacts.add_neq_iff csq_new) in n5.
      intuition.
    + apply H0; auto.
Qed.

Lemma step4_aux_correct :
  forall a b c csq_orig t csq_new,
    TS.In [a,b,c] csq_orig ->
    TS.In t csq_orig ->
    Conseqs_imm csq_orig csq_new ->
    Conseqs_imm csq_orig (step4_aux a b c csq_orig t csq_new).
Proof.
  intros.
  destruct t; destruct p.
  unfold step4_aux.
  unfold Conseqs_imm.
  intros.
  destruct (N2.eq_dec (b, c) (n, n1)).
  - case_eq (TS.mem [n0, a, c] csq_orig).
    + intros.
      rewrite H3 in H2.
      unfold insert in H2.
      case_eq (TS.mem [a, b, n0] csq_orig); intro.
      * rewrite H4 in *; auto.
      * rewrite H4 in *.
        unfold Conseqs_imm in H1.
        destruct t; destruct p.
        compute in e; intuition; subst.
        destruct (Triangle.eq_dec [a,n,n0] [n2,n3,n4]).
        { compute in e.
          intuition; subst.
          apply (Rule4 csq_orig n2 n3 n4 n1); repeat (intuition).
        }
        apply (SetFacts.add_neq_iff csq_new) in n5.
        intuition.
    + intros.
      rewrite H3 in H2.
      intuition.
  - intuition.
Qed.

Lemma step4_correct : step_correct step4.
Proof.
  unfold step_correct.
  intros csq_orig csq_new (a, (b, c)).
  unfold step4.
  intros.
  eapply SetProps.fold_rec_nodep.
  + auto.
  + intros.
    eapply step4_aux_correct; eauto.
Qed.

Lemma step5_aux_aux_correct :
  forall a b c d csq_orig csq_new t,
    TS.In [a,b,c] csq_orig ->
    TS.In [a,b,d] csq_orig ->
    TS.In t csq_orig ->
    Conseqs_imm csq_orig csq_new ->
    Conseqs_imm csq_orig (step5_aux_aux a b c d csq_orig t csq_new).
Proof.
  intros a b c d csq_orig csq_new (a',(b',e)) Habc Habd Ht Hacc.
  unfold step5_aux_aux.
  flatten; auto.
  compute in e0.
  destruct e0 as [ea eb].
  symmetry in ea,eb. subst.
  unfold insert.
  flatten; auto.
  unfold Conseqs_imm.
  intros (x,(y,z)) Ht'.
  destruct (Triangle.eq_dec [x, y, z] [a, c, e]).
  + compute in e0. destruct e0 as [ea e0]. destruct e0 as [ec ee]. subst.
    apply andb_prop in Eq. destruct Eq as [Hmem1 Hmem2].
    apply SetFacts.mem_2 in Hmem1. apply SetFacts.mem_2 in Hmem2.
    apply (Rule5 csq_orig a b c d e); try assumption.
  + apply Hacc. apply SetFacts.add_3 with (x := [a, c, e]).
    * compute. compute in n. intuition.
    * exact Ht'.
Qed.


Lemma step5_aux_correct :
  forall a b c csq_orig csq_new t,
    TS.In [a,b,c] csq_orig ->
    TS.In t csq_orig ->
    Conseqs_imm csq_orig csq_new ->
    Conseqs_imm csq_orig (step5_aux a b c csq_orig t csq_new).
Proof.
  intros a b c csq_orig csq_new (a',(b',e)) Habc Ht Hacc.
  unfold step5_aux.
  flatten; auto.
  eapply SetProps.fold_rec_nodep; eauto.
  intros.
  compute in e0. destruct e0 as [ea eb]. subst.
  apply step5_aux_aux_correct; auto.
Qed.

Lemma step5_correct : step_correct step5.
Proof.
  unfold step_correct, step5.
  intros csq_orig csq_new (a,(b,c)) T_in_csq Hrec.
  eapply SetProps.fold_rec_nodep; eauto.
  intros. apply step5_aux_correct; auto.
Qed.

Lemma fold_step_correct :
  forall csq_new csq_orig step,
    Conseqs_imm csq_orig csq_new ->
    step_correct step ->
    Conseqs_imm csq_orig (TS.fold (step csq_orig) csq_orig csq_new).
Proof.
  intros; eapply SetProps.fold_rec_nodep; intros; eauto.
Qed.

Lemma union_csq_imm: forall old new,
  Conseqs_imm old new -> Conseqs_imm old (TS.union old new).
Proof.
  intros old new H x Hincl.
  apply TS.union_spec in Hincl.
  destruct Hincl; eauto.
Qed.


Lemma step145_correct : forall ts, Conseqs_imm ts (csq_proj (step145 ts)).
Proof.
  Hint Resolve step1_correct step4_correct step5_correct fold_step_correct.
  intros orig. destruct (step145 orig) eqn:eq.
  + intro. simpl in *. unfold step145 in eq. flatten eq.
    apply TS.is_empty_spec in Eq. apply SetProps.empty_is_empty_1 in Eq. eauto.
  + simpl in *. unfold step145 in *. flatten eq.
    match goal with
    | [ |- Conseqs_imm orig (TS.union orig ?x)] =>
      assert (Conseqs_imm orig x)
    end.
    { repeat (eapply fold_step_correct); eauto. intro. intro. constructor 1. apply TS.empty_spec in H.
      contradiction. }
    eauto using union_csq_imm.
Qed.

Inductive Conseqs : TS.t -> TS.t -> Prop :=
  | Imm : forall ts ts', Conseqs_imm ts ts' -> Conseqs ts ts'
  | Trans : forall ts ts' ts'', Conseqs_imm ts ts' -> Conseqs ts' ts'' -> Conseqs ts ts''.

Hint Constructors Conseqs.

Lemma step145_effective_correct : forall ts csq, inr csq = step145 ts -> Conseqs_imm ts csq.
Proof.
  Hint Resolve step145_correct.
  intros. replace csq with (csq_proj (inr csq)) by auto.
  rewrite H. auto.
Qed.

Theorem sat145_correct : forall fuel ts, Conseqs ts (sat145 ts fuel).
Proof.
  induction fuel; simpl; auto.
  intro. flatten. unfold step145 in Eq; flatten Eq; auto.
  eapply Trans; [| eauto].
  eapply step145_effective_correct; auto.
Qed.


Definition inconsistent csq :=
  TS.exists_ (fun t => match t with [a,b,c] => TS.mem [c, b, a] csq end) csq.

Definition distinctb a b c :=
  if eq_nat_dec a b
  then false
  else (if eq_nat_dec b c
        then false
        else (if eq_nat_dec c a
             then false
             else true)).

Definition distinct (a b c : nat) := a ≠ b ∧ b ≠ c ∧ c ≠ a.
Hint Unfold distinct.

Lemma distinct_spec : forall a b c, distinctb a b c = true -> distinct a b c.
Proof. intros. unfold distinctb in *. flatten H. unfold distinct. auto. Qed.

  Definition sym_triangle (t : Triangle.t) :=
    match t with
      [a, b, c] => [c, b, a]
    end.
  
Fixpoint refute' (worklist : list Triangle.t) (problem : TS.t) :=
  match worklist with
      | nil => false
      | [m,n,p]::wl =>
        if distinctb m n p then
          if inconsistent problem then true
          else if negb (refute' wl (sat145 (TS.add [m,n,p] problem) 1000))
               then false
               else refute' wl (sat145 (TS.add [p,n,m] problem) 1000)
        else refute' wl problem
  end.

Lemma refute'_step worklist problem : refute' worklist problem =
  match worklist with
      | nil => false
      | [m,n,p]::wl =>
        if distinctb m n p then
          if inconsistent problem then true
          else if negb (refute' wl (sat145 (TS.add [m,n,p] problem) 1000))
               then false
               else refute' wl (sat145 (TS.add [p,n,m] problem) 1000)
        else refute' wl problem
  end.
Proof.
 destruct worklist; reflexivity.
Qed.

Fixpoint enumerate len n : list (list nat) :=
  match n with
      O => match len with
               | O => nil::nil
               | S p => nil
           end
    | S p =>
      match len with
        | O => nil::nil
        | S l =>
          List.map (fun e => 0::List.map (fun x => x + 1) e)
                   (enumerate l p)++
                   List.map (fun e => List.map (fun x => x + 1) e)
                   (enumerate (S l) p)
      end
  end.

Definition triplets_to_triangles :=
  List.map (
      fun triplet => match triplet with
                       | a::b::c::nil => [a,b,c]
                       | _ => [1,1,1]
                     end
    ).

Definition max_triangle t := match t with [a,b,c] => max (max a b) c end.
Definition support ts := TS.fold (fun t => fun m => max m (max_triangle t)) ts 0. 

Definition refute l :=
  refute' (triplets_to_triangles (enumerate 3 (S (support l)))) (sat145 l 1000).

Definition canonical_problem := {{[1,2,3], [2,3,4], [1,5,2], [2,5,3], [4,3,5], [1,4,5]}}.
(* 123 234 152 253 354 145 :
             5
            /|
           / |
          2--3
         /   |
        /    |
       1     4 
*)
(* Compute (refute canonical_problem). *)

Notation "x ∈ y" := (TS.In x y ) (at level 10).

Section FINAL.
  Variable A : Type.
  Variable oriented : A -> A -> A -> Prop.
  Variable inj : nat -> A.
  Variable bound : nat.
  Hypothesis inj_inj : ∀ x y, x < bound -> y < bound -> inj x = inj y -> x = y.
  Definition δ t := match t with [x, y, z] => oriented (inj x) (inj y) (inj z) end.
  Definition Δ := TS.For_all δ.
  Definition b_pb ts := support ts < bound.

  Variable rule1 : forall a b c, δ [a, b, c] -> δ [b, c, a].

  Variable rule2 : forall a b c, δ [a, b, c] -> ¬δ [c, b, a].

  Variable rule3 : forall a b c, 
  a < bound -> b < bound -> c < bound ->
  a ≠ b -> b ≠ c -> c ≠ a -> δ [a, b, c] ∨ δ [c, b, a].

  Variable rule4 : forall a b c d, δ [a, b, d] -> δ [b, c, d] -> δ [c, a, d] -> δ [a, b, c].
  Variable rule5 : forall a b c d e, δ [a, b, c] -> δ [a, b, d] -> δ [a, b, e] ->
                      δ [a, c, d] -> δ [a, d, e] -> δ [a, c, e].
  Variable hyps : TS.t.
  Hypothesis hyps_spec : Δ hyps.
  Variable ziel : Triangle.t.
  Hypothesis hyps_b : b_pb (TS.add (sym_triangle ziel) hyps).
  Hypothesis ziel_not_degenerate : match ziel with [a, b, c] => distinct a b c end.

  Lemma Conseqs_imm_spec : forall ts ts', Conseqs_imm ts ts' -> Δ ts -> Δ ts'.
  Proof.
    intros ts ts' H HΔ x Hx.
    assert (csq : Conseq ts x) by intuition.
    induction csq; [| | apply rule4 with d | apply rule5 with b d]; try intuition.
  Qed.

  Lemma Conseqs_spec : forall ts ts', Conseqs ts ts' -> Δ ts -> Δ ts'.
    intros ts ts' csq sp.
    induction csq; auto using (Conseqs_imm_spec ts ts').
  Qed.

  Lemma sat145_spec : forall ts fuel, Δ ts -> Δ (sat145 ts fuel).
  Proof.
    intro. intro.
    assert (Conseqs ts (sat145 ts fuel)) by (apply sat145_correct).
    intro; apply (Conseqs_spec ts (sat145 ts fuel)); repeat assumption.
  Qed.

  Lemma inconsistent_spec : forall ts, Δ ts -> inconsistent ts = true -> False.
  Proof.
    intros ts Hts H. unfold inconsistent in *.
    apply TS.exists_spec in H.
    + destruct H as [[a [b c]] [Hx Hmem]]. apply TS.mem_spec in Hmem. eapply rule2; eauto.
    + intros x y Heq.
      apply eq_is_eq in Heq. subst. exact eq_refl.
  Qed.
      
  Lemma Δ_is_additive : forall ts t, δ t -> Δ ts -> Δ (TS.add t ts).
  Proof.
    intros ts t Ht Hts x Hx.
    apply TS.add_spec in Hx; destruct Hx as [Heq | Hin];
      [apply eq_is_eq in Heq; congruence | auto].
  Qed.
    
  Lemma refute'_spec_axiom3 ts a b c (DIST: distinct a b c):
      a < bound -> b < bound -> c < bound ->
      Δ ts -> ¬Δ (TS.add [a, b, c] ts) -> ¬Δ (TS.add [c, b, a] ts) -> False.
  Proof.
    intros. destruct DIST as [Ha [Hb Hc]].
    destruct (rule3 a b c); eauto using rule2, Δ_is_additive.
  Qed.
    
  Lemma refute'_spec : forall wl ts,
     (forall t, In t wl ->
      fst t < bound /\ fst (snd t) < bound /\ snd (snd t) < bound) ->
     Δ ts -> refute' wl ts = true -> False.
  Proof.
    induction wl as [ | a wl IHwl]; intros ts wlb H H0. 
    + discriminate.
    + destruct a as (x1, (x2, x3)). rewrite refute'_step in H0.
      flatten H0; [eauto using inconsistent_spec | | eauto].
      match goal with [H : negb _ = false |- _] => apply negb_false_iff in H end.
      eapply refute'_spec_axiom3 with (ts := ts) (a := x1) (b := x2) (c := x3);
        eauto; intros; eauto using sat145_spec, distinct_spec.
      destruct (wlb [x1, x2, x3]) as [x1b [x2b x3b]];[left; reflexivity | exact x1b].
      destruct (wlb [x1, x2, x3]) as [x1b [x2b x3b]];[left; reflexivity | exact x2b].
      destruct (wlb [x1, x2, x3]) as [x1b [x2b x3b]];[left; reflexivity | exact x3b].
      intros Delta; apply (IHwl (sat145 (TS.add [x1,x2,x3] ts) 1000)).
      intros t twl; apply wlb; right; assumption.
      apply sat145_spec; assumption.
      assumption.
      intros Delta; apply (IHwl (sat145 (TS.add [x3,x2,x1] ts) 1000)).
      intros t twl; apply wlb; right; assumption.
      apply sat145_spec; assumption.
      assumption.
      apply (IHwl ts); auto.
     intros t twl; apply wlb; right; assumption.
  Qed.

Lemma enumerate_lt : forall p n t l, In t l -> In l (enumerate p n) -> t < n.
Proof.
intros p n; revert p; induction n.
 intros [ | p] t l intl.
  intros [ql | []]; rewrite <- ql in intl; simpl in intl; contradiction.
 simpl; contradiction.
intros [ | p] t l intl; simpl. 
 intros [ql | []]; rewrite <- ql in intl; simpl in intl; contradiction.
intros ina; apply in_app_or in ina; destruct ina as [in1 | in2].
 rewrite in_map_iff in in1; destruct in1 as [t' [qt' Pt']].
 rewrite <- qt' in intl; simpl in intl; destruct intl as [t1 | tt'].
  omega.
 rewrite in_map_iff in tt'; destruct tt' as [x [qx inx]].
 assert (IHn' := IHn _ _ _ inx Pt'); omega.
rewrite in_map_iff in in2; destruct in2 as [t' [qt' Pt']].
rewrite <- qt' in intl; rewrite in_map_iff in intl.
destruct intl as [x [qx inx]].
assert (IHn' := IHn _ _ _ inx Pt'); omega.
Qed.

Lemma support_spec1 n ts :
  (forall t,
     TS.mem t ts = true -> fst t <= n /\ fst (snd t) <= n /\ snd (snd t) <= n) ->
  support ts <= n.
Proof.
unfold support; rewrite TS.fold_spec; intros cts.
assert (cts' : forall t, existsb (SetProps.FM.eqb t) (TS.elements ts) = true ->
           fst t <= n /\ fst (snd t) <= n /\ snd (snd t) <= n).
 now intros t; rewrite <- SetProps.FM.elements_b; apply cts.
revert cts'; clear cts.
assert (nge0 : 0 <= n) by omega.
revert nge0; generalize 0.
induction (TS.elements ts) as [ | e l IHl]; simpl; intros p pn cts.
 assumption.
assert (max_n : max p (max_triangle e) <= n).
 apply Max.max_lub;[assumption | ].
 destruct (cts e) as [an [bn cn]].
  unfold SetProps.FM.eqb; destruct (TS.E.eq_dec e e) as [ _ | n0];[reflexivity | ].
  case n0; reflexivity.
 unfold max_triangle; destruct e as [a [b c]].
 apply Max.max_lub;[apply Max.max_lub | ]; assumption.
assert (cts' : forall t, existsb (SetProps.FM.eqb t) l = true ->
         fst t <= n /\ fst (snd t) <= n /\ snd (snd t) <= n).
 intros t ext; apply cts; rewrite orb_comm, ext; reflexivity.
clear cts; apply IHl; assumption.
Qed.


Lemma support_spec2 ts : forall t, TS.mem t ts = true -> 
  fst t <= support ts /\ fst (snd t) <= support ts /\ snd (snd t) <= support ts.
unfold support.
intros t; rewrite TS.fold_spec, SetProps.FM.elements_b.
assert (fold_max : forall l n, n <= fold_left (fun a e => max a (max_triangle e)) l n).
 induction l as [ | a l IHl]; intros n.
  now apply le_n. 
 simpl; apply le_trans with (max n (max_triangle a)).
  now apply Max.le_max_l. 
 now apply IHl.
generalize 0; induction (TS.elements ts) as [ | a l IHl].
 intros n h; discriminate h.
simpl; intros n exal.
apply orb_prop in exal; destruct exal as [ta | it].
 repeat apply conj; 
   (apply le_trans with (max n (max_triangle a));
    [unfold SetProps.FM.eqb in ta;
   destruct (TS.E.eq_dec t a) as [ta' | _];
      [rewrite ta'; apply le_trans with (2:= (Max.le_max_r _ _));
        unfold max_triangle; destruct a as [e1 [e2 e3]] | discriminate] | apply fold_max]).
   now apply le_trans with (2 := Max.le_max_l _ _), Max.le_max_l.
  now apply le_trans with (2 := Max.le_max_l _ _), Max.le_max_r.
 now apply Max.le_max_r.
apply IHl; assumption.
Qed.

Lemma enumerate_len p n :
  forall t, In t (enumerate p n) -> length t = p.
revert p; induction n as [|n IHn].
 simpl; intros [ | p]; simpl.
  intros t' [nilt | []]; rewrite <- nilt; reflexivity.
 contradiction.
simpl; intros [ | p] t; simpl.
 intros [nilt | []]; rewrite <- nilt; reflexivity.
intros intl; apply in_app_or in intl; destruct intl as [intl | intl];
rewrite in_map_iff in intl; destruct intl as [x [qx inx]]; rewrite <- qx;
apply IHn in inx; simpl; rewrite map_length; auto.
Qed.

Lemma b_ps_enum ts :
 b_pb ts -> forall t, In t (triplets_to_triangles (enumerate 3 (S (support ts)))) ->
     fst t < bound /\ fst (snd t) < bound /\ snd (snd t) < bound.
Proof.
intros hb t int.
generalize (enumerate_lt 3 (S (support ts))); revert t int.
generalize (enumerate_len 3 (S (support ts))).
induction (enumerate 3 (S (support ts))) as [ | t1 ts' Ih].
 simpl; contradiction.
simpl; intros len t; generalize (len t1 (or_introl (refl_equal _))).
destruct t1 as [ | a [|b [ |c [ | d]]]]; try discriminate.
intros _ [tabc | tts'] ils.
 repeat apply conj; apply lt_le_trans with (2 := hb), ils with (l:=(a::b::c::nil)); 
  try (rewrite <- tabc; simpl; tauto) || tauto.
apply Ih in tts'.
  intros; exact tts'.
 intros t' int'; apply len; right; assumption.
intros t' l int' inl; apply ils with l ; tauto.
Qed.

  Lemma refute_spec : forall ts, b_pb ts -> Δ ts -> refute ts = true -> False.
  Proof.
    intros ts bts Delta; unfold refute.
    apply refute'_spec;[ | apply sat145_spec;assumption].
    apply b_ps_enum; exact bts.
  Qed.    

  Theorem hyps_implies_ziel :  
    refute (TS.add (sym_triangle ziel) hyps) = true -> δ ziel.
  Proof.
    intros H.
    destruct ziel as (a, (b, c)). destruct ziel_not_degenerate as [Ha [Hb Hc]].
    assert ( tmp := support_spec2 (TS.add [c, b, a] hyps) [c, b, a]).
    simpl in tmp |- *.
    assert (tmp' : TS.mem [c, b, a] (TS.add [c, b, a] hyps) = true).
     rewrite SetFacts.add_b; unfold SetFacts.eqb; 
     destruct (TS.E.eq_dec [c, b, a] [c, b, a]) as [_ | abs];[|case abs];
     reflexivity.
    apply tmp in tmp'.
    destruct (rule3 a b c); eauto.
       apply le_lt_trans with (2 := hyps_b); tauto.    
      apply le_lt_trans with (2 := hyps_b); tauto.    
     apply le_lt_trans with (2 := hyps_b); tauto.    
    exfalso. simpl in H.
    eapply refute_spec with (TS.add [c, b, a] hyps); eauto.
    apply Δ_is_additive; auto.
  Qed.    

End FINAL.
