From heap_lang Require Import
  prelude.
From heap_lang.language Require Import
  notations
  proofmode.
From heap_lang.std Require Export
  base.

Notation "&Nil" := (
  InjL #()
)(only parsing
).
Notation "&&Nil" := (
  InjLV #()
)(only parsing
).
Notation "&Cons" := (
  λ e1 e2, InjR (e1, e2)
)(only parsing
).
Notation "&&Cons" := (
  λ v1 v2, InjRV (v1, v2)
)(only parsing
).

Notation "'match:' e0 'with' 'Nil' => e1 | 'Cons' x1 , x2 => e2 'end'" := (
  Match
    e0
    <>%binder
    e1
    "__match" (Let x1%binder (Fst "__match") (Let x2%binder (Snd "__match") e2))
)(e0, e1, x1, x2, e2 at level 200,
  only parsing
) : expr_scope.
Notation "'match:' e0 'with' | 'Nil' => e1 | 'Cons' x1 , x2 => e2 'end'" := (
  Match
    e0
    <>%binder
    e1
    "__match" (Let x1%binder (Fst "__match") (Let x2%binder (Snd "__match") e2))
)(e0, e1, x1, x2, e2 at level 200,
  only parsing
) : expr_scope.

Section heap_GS.
  Context `{heap_GS : !heapGS Σ}.

  Implicit Types i j : nat.
  Implicit Types v w t fn acc : val.
  Implicit Types vs vs_left vs_right ws : list val.

  Definition lst_cons : val :=
    λ: "v" "t",
      &Cons "v" "t".

  Definition lst_singleton : val :=
    λ: "v",
      &Cons "v" &Nil.

  Definition lst_head : val :=
    λ: "t",
      match: "t" with
      | Nil =>
          Fail
      | Cons "v", <> =>
          "v"
      end.
  Definition lst_tail : val :=
    λ: "t",
      match: "t" with
      | Nil =>
          Fail
      | Cons <>, "t" =>
          "t"
      end.

  Definition lst_is_empty : val :=
    λ: "t",
      match: "t" with
      | Nil =>
          #true
      | Cons <>, <> =>
          #false
      end.

  Definition lst_get : val :=
    rec: "lst_get" "t" "i" :=
      if: "i" ≤ #0 then (
        lst_head "t"
      ) else (
        "lst_get" (lst_tail "t") ("i" - #1)
      ).

  #[local] Definition lst_initi_aux : val :=
    rec: "lst_initi_aux" "sz" "fn" "i" :=
      if: "sz" ≤ "i" then (
        &Nil
      ) else (
        let: "v" := "fn" "i" in
        &Cons "v" ("lst_initi_aux" "sz" "fn" (#1 + "i"))
      ).
  Definition lst_initi : val :=
    λ: "sz" "fn",
      lst_initi_aux "sz" "fn" #0.
  Definition lst_init : val :=
    λ: "sz" "fn",
      lst_initi "sz" (λ: <>, "fn" #()).

  #[local] Definition lst_foldli_aux : val :=
    rec: "lst_foldli_aux" "t" "acc" "fn" "i" :=
      match: "t" with
      | Nil =>
          "acc"
      | Cons "v", "t" =>
          "lst_foldli_aux" "t" ("fn" "acc" "i" "v") "fn" (#1 + "i")
      end.
  Definition lst_foldli : val :=
    λ: "t" "acc" "fn",
      lst_foldli_aux "t" "acc" "fn" #0.
  Definition lst_foldl : val :=
    λ: "t" "acc" "fn",
      lst_foldli "t" "acc" (λ: "acc" <>, "fn" "acc").

  #[local] Definition lst_foldri_aux : val :=
    rec: "lst_foldri_aux" "t" "fn" "acc" "i" :=
      match: "t" with
      | Nil =>
          "acc"
      | Cons "v", "t" =>
          "fn" "i" "v" ("lst_foldri_aux" "t" "fn" "acc" (#1 + "i"))
      end.
  Definition lst_foldri : val :=
    λ: "t" "fn" "acc",
      lst_foldri_aux "t" "fn" "acc" #0.
  Definition lst_foldr : val :=
    λ: "t" "fn" "acc",
      lst_foldri "t" (λ: <>, "fn") "acc".

  Definition lst_size : val :=
    λ: "t",
      lst_foldl "t" #0 (λ: "acc" <>, #1 + "acc").

  Definition lst_rev : val :=
    λ: "t",
      lst_foldl "t" &Nil (λ: "acc" "v", &Cons "v" "acc").

  Definition lst_app : val :=
    λ: "t1" "t2",
      lst_foldr "t1" lst_cons "t2".
  Definition lst_snoc : val :=
    λ: "t" "v",
      lst_app "t" (lst_singleton "v").

  Definition lst_iteri : val :=
    λ: "t" "fn",
      lst_foldli "t" #() (λ: <>, "fn").
  Definition lst_iter : val :=
    λ: "t" "fn",
      lst_iteri "t" (λ: <>, "fn").

  #[local] Definition lst_mapi_aux : val :=
    rec: "lst_mapi_aux" "t" "fn" "i" :=
      match: "t" with
      | Nil =>
          &Nil
      | Cons "v", "t" =>
          let: "v" := "fn" "i" "v" in
          let: "t" := "lst_mapi_aux" "t" "fn" (#1 + "i") in
          &Cons "v" "t"
      end.
  Definition lst_mapi : val :=
    λ: "t" "fn",
      lst_mapi_aux "t" "fn" #0.
  Definition lst_map : val :=
    λ: "t" "fn",
      lst_mapi "t" (λ: <>, "fn").

  Inductive lst_model_inner : val → list val → Prop :=
    | lst_model_nil :
        lst_model_inner &&Nil []
    | lst_model_cons v t vs :
        lst_model_inner t vs →
        lst_model_inner (&&Cons v t) (v :: vs).
  #[local] Hint Constructors lst_model_inner : core.

  Definition lst_model t vs : iProp Σ :=
    ⌜lst_model_inner t vs⌝.

  #[global] Instance lst_model_persistent t vs :
    Persistent (lst_model t vs).
  Proof.
    apply _.
  Qed.
  #[global] Instance lst_model_timeless t vs :
    Timeless (lst_model t vs).
  Proof.
    apply _.
  Qed.

  Lemma lst_nil_spec :
    ⊢ lst_model &&Nil [].
  Proof.
    iSmash.
  Qed.

  Lemma lst_cons_spec v t vs :
    {{{
      lst_model t vs
    }}}
      lst_cons v t
    {{{ t',
      RET t';
      lst_model t' (v :: vs)
    }}}.
  Proof.
    iIntros "%Φ" ([]) "HΦ".
    all: wp_rec; wp_pures.
    all: iApply "HΦ"; auto.
  Qed.

  Lemma lst_singleton_spec v :
    {{{ True }}}
      lst_singleton v
    {{{ t,
      RET t;
      lst_model t [v]
    }}}.
  Proof.
    iIntros "%Φ _ HΦ".
    wp_rec. wp_pures.
    iApply "HΦ". auto.
  Qed.

  Lemma lst_head_spec t vs v vs' :
    vs = v :: vs' →
    {{{
      lst_model t vs
    }}}
      lst_head t
    {{{
      RET v; True
    }}}.
  Proof.
    iIntros (->) "%Φ %Ht HΦ". invert Ht.
    iSmash.
  Qed.

  Lemma lst_tail_spec t vs v vs' :
    vs = v :: vs' →
    {{{
      lst_model t vs
    }}}
      lst_tail t
    {{{ t',
      RET t';
      lst_model t' vs'
    }}}.
  Proof.
    iIntros (->) "%Φ %Ht HΦ". invert Ht.
    iSmash.
  Qed.

  Lemma lst_is_empty_spec t vs :
    {{{
      lst_model t vs
    }}}
      lst_is_empty t
    {{{
      RET #(bool_decide (vs = [])); True
    }}}.
  Proof.
    iIntros "%Φ" ([]) "HΦ".
    all: iSmash.
  Qed.

  Lemma lst_get_spec v t (i : Z) vs :
    vs !! Z.to_nat i = Some v →
    {{{
      lst_model t vs
    }}}
      lst_get t #i
    {{{
      RET v; True
    }}}.
  Proof.
    remember (Z.to_nat i) as j eqn:Hj.
    iInduction j as [| j] "IH" forall (t i vs Hj).
    all: iIntros "%Hlookup %Φ %Ht HΦ".
    all: pose proof Hlookup as Hi%lookup_lt_Some.
    all: destruct vs as [| v' vs]; simpl in Hi; first lia.
    all: wp_rec; wp_pures.
    - rewrite bool_decide_eq_true_2; last lia. wp_pures.
      wp_apply lst_head_spec; [done | iSmash |].
      apply (inj Some) in Hlookup. iSmash.
    - rewrite bool_decide_eq_false_2; last lia. wp_pures.
      wp_apply lst_tail_spec; [done | iSmash |]. iIntros "%t' %Ht'".
      wp_apply ("IH" with "[] [//] [//] HΦ").
      iSmash.
  Qed.

  #[local] Lemma lst_initi_aux_spec vs_left Ψ sz fn i :
    i ≤ Z.to_nat sz →
    i = length vs_left →
    {{{
      ▷ Ψ i vs_left ∗
      □ (
        ∀ i vs,
        ⌜i < Z.to_nat sz ∧ i = length vs⌝ -∗
        Ψ i vs -∗
        WP fn #i {{ v,
          ▷ Ψ (S i) (vs ++ [v])
        }}
      )
    }}}
      lst_initi_aux #sz fn #i
    {{{ t vs_right,
      RET t;
      ⌜(length vs_left + length vs_right)%nat = Z.to_nat sz⌝ ∗
      lst_model t vs_right ∗
      Ψ (Z.to_nat sz) (vs_left ++ vs_right)
    }}}.
  Proof.
    remember (Z.to_nat sz - i) as j eqn:Hj.
    iInduction j as [| j] "IH" forall (vs_left i Hj).
    all: iIntros "%Hi1 %Hi2 %Φ (HΨ & #Hfn) HΦ".
    all: wp_rec; wp_pures.
    - rewrite bool_decide_eq_true_2; last lia. wp_pures.
      iApply ("HΦ" $! _ []).
      rewrite !right_id. assert (Z.to_nat sz = i) as <- by lia. iSmash.
    - rewrite bool_decide_eq_false_2; last lia. wp_pures.
      wp_apply (wp_wand with "(Hfn [] HΨ)"); first iSmash. iIntros "%v HΨ".
      wp_pures.
      rewrite Z.add_1_l -Nat2Z.inj_succ.
      wp_apply ("IH" $! (vs_left ++ [v]) (S i) with "[] [] [] [$HΨ //]"); rewrite ?app_length; [iSmash.. |]. iIntros "%t %vs_right (%Hvs_right & %Ht & HΨ)".
      wp_pures.
      iApply ("HΦ" $! _ (v :: vs_right)).
      rewrite -assoc. simpl in Hvs_right. iSteps. auto with iFrame.
  Qed.
  Lemma lst_initi_spec Ψ sz fn :
    {{{
      ▷ Ψ 0 [] ∗
      □ (
        ∀ i vs,
        ⌜i < Z.to_nat sz ∧ i = length vs⌝ -∗
        Ψ i vs -∗
        WP fn #i {{ v,
          ▷ Ψ (S i) (vs ++ [v])
        }}
      )
    }}}
      lst_initi #sz fn
    {{{ t vs,
      RET t;
      ⌜length vs = Z.to_nat sz⌝ ∗
      lst_model t vs ∗
      Ψ (Z.to_nat sz) vs
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_initi_aux_spec [] Ψ with "[$HΨ $Hfn] HΦ"); simpl; lia.
  Qed.
  Lemma lst_initi_spec' Ψ sz fn :
    {{{
      ▷ Ψ 0 [] ∗
      ( [∗ list] i ∈ seq 0 (Z.to_nat sz),
        ∀ vs,
        ⌜i = length vs⌝ -∗
        Ψ i vs -∗
        WP fn #i {{ v,
          ▷ Ψ (S i) (vs ++ [v])
        }}
      )
    }}}
      lst_initi #sz fn
    {{{ t vs,
      RET t;
      ⌜length vs = Z.to_nat sz⌝ ∗
      lst_model t vs ∗
      Ψ (Z.to_nat sz) vs
    }}}.
  Proof.
    iIntros "%Φ (HΨ & Hfn) HΦ".
    match goal with |- context [big_opL bi_sep (λ _, ?Ξ') _] => set Ξ := Ξ' end.
    pose (Ψ' i vs := (
      Ψ i vs ∗
      [∗ list] j ∈ seq i (Z.to_nat sz - i), Ξ j
    )%I).
    wp_apply (lst_initi_spec Ψ' with "[$HΨ Hfn]"); last iSmash.
    rewrite Nat.sub_0_r. iFrame. iIntros "!> %i %vs (%Hi1 & %Hi2) (HΨ & HΞ)".
    destruct (Nat.lt_exists_pred 0 (Z.to_nat sz - i)) as (k & Hk & _); first lia. rewrite Hk.
    rewrite -cons_seq. iDestruct "HΞ" as "(Hfn & HΞ)".
    wp_apply (wp_wand with "(Hfn [//] HΨ)"). iSteps.
    rewrite Nat.sub_succ_r Hk //.
  Qed.
  Lemma lst_initi_spec_disentangled Ψ sz fn :
    {{{
      □ (
        ∀ i,
        ⌜i < Z.to_nat sz⌝ -∗
        WP fn #i {{ v,
          ▷ Ψ i v
        }}
      )
    }}}
      lst_initi #sz fn
    {{{ t vs,
      RET t;
      ⌜length vs = Z.to_nat sz⌝ ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i v
      )
    }}}.
  Proof.
    iIntros "%Φ #Hfn HΦ".
    pose (Ψ' i vs := (
      [∗ list] j ↦ v ∈ vs, Ψ j v
    )%I).
    wp_apply (lst_initi_spec Ψ'); last iSmash.
    rewrite /Ψ'. iSteps.
    rewrite big_sepL_snoc. iSmash.
  Qed.
  Lemma lst_initi_spec_disentangled' Ψ sz fn :
    {{{
      ( [∗ list] i ∈ seq 0 (Z.to_nat sz),
        WP fn #i {{ v,
          ▷ Ψ i v
        }}
      )
    }}}
      lst_initi #sz fn
    {{{ t vs,
      RET t;
      ⌜length vs = Z.to_nat sz⌝ ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i v
      )
    }}}.
  Proof.
    iIntros "%Φ Hfn HΦ".
    pose (Ψ' i vs := (
      [∗ list] j ↦ v ∈ vs, Ψ j v
    )%I).
    wp_apply (lst_initi_spec' Ψ' with "[Hfn]"); last iSmash.
    rewrite /Ψ'. iSteps.
    iApply (big_sepL_impl with "Hfn"). iSteps.
    rewrite big_sepL_snoc. iSmash.
  Qed.

  Lemma lst_init_spec Ψ sz fn :
    {{{
      ▷ Ψ 0 [] ∗
      □ (
        ∀ i vs,
        ⌜i < Z.to_nat sz ∧ i = length vs⌝ -∗
        Ψ i vs -∗
        WP fn #() {{ v,
          ▷ Ψ (S i) (vs ++ [v])
        }}
      )
    }}}
      lst_init #sz fn
    {{{ t vs,
      RET t;
      ⌜length vs = Z.to_nat sz⌝ ∗
      lst_model t vs ∗
      Ψ (Z.to_nat sz) vs
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_initi_spec Ψ with "[$HΨ] HΦ").
    iSmash.
  Qed.
  Lemma lst_init_spec' Ψ sz fn :
    {{{
      ▷ Ψ 0 [] ∗
      ( [∗ list] i ∈ seq 0 (Z.to_nat sz),
        ∀ vs,
        ⌜i = length vs⌝ -∗
        Ψ i vs -∗
        WP fn #() {{ v,
          ▷ Ψ (S i) (vs ++ [v])
        }}
      )
    }}}
      lst_init #sz fn
    {{{ t vs,
      RET t;
      ⌜length vs = Z.to_nat sz⌝ ∗
      lst_model t vs ∗
      Ψ (Z.to_nat sz) vs
    }}}.
  Proof.
    iIntros "%Φ (HΨ & Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_initi_spec' Ψ with "[$HΨ Hfn] HΦ").
    iApply (big_sepL_impl with "Hfn").
    iSmash.
  Qed.
  Lemma lst_init_spec_disentangled Ψ sz fn :
    {{{
      □ (
        ∀ i,
        ⌜i < Z.to_nat sz⌝ -∗
        WP fn #() {{ v,
          ▷ Ψ i v
        }}
      )
    }}}
      lst_init #sz fn
    {{{ t vs,
      RET t;
      ⌜length vs = Z.to_nat sz⌝ ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i v
      )
    }}}.
  Proof.
    iIntros "%Φ #Hfn HΦ".
    wp_rec.
    wp_smart_apply (lst_initi_spec_disentangled Ψ with "[] HΦ").
    iSmash.
  Qed.
  Lemma lst_init_spec_disentangled' Ψ sz fn :
    {{{
      ( [∗ list] i ∈ seq 0 (Z.to_nat sz),
        WP fn #() {{ v,
          ▷ Ψ i v
        }}
      )
    }}}
      lst_init #sz fn
    {{{ t vs,
      RET t;
      ⌜length vs = Z.to_nat sz⌝ ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i v
      )
    }}}.
  Proof.
    iIntros "%Φ Hfn HΦ".
    wp_rec.
    wp_smart_apply (lst_initi_spec_disentangled' Ψ with "[Hfn] HΦ").
    iApply (big_sepL_impl with "Hfn").
    iSmash.
  Qed.

  #[local] Lemma lst_foldli_aux_spec vs_left Ψ vs t vs_right acc fn i :
    vs = vs_left ++ vs_right →
    i = length vs_left →
    {{{
      ▷ Ψ i vs_left acc ∗
      lst_model t vs_right ∗
      □ (
        ∀ i v acc,
        ⌜vs !! i = Some v⌝ -∗
        Ψ i (take i vs) acc -∗
        WP fn acc #i v {{ acc,
          ▷ Ψ (S i) (take i vs ++ [v]) acc
        }}
      )
    }}}
      lst_foldli_aux t acc fn #i
    {{{ acc,
      RET acc;
      Ψ (length vs) vs acc
    }}}.
  Proof.
    iInduction vs_right as [| v vs_right] "IH" forall (vs_left t acc i).
    all: iIntros (->); rewrite app_length.
    all: iIntros "%Hi %Φ (HΨ & %Ht & #Hfn) HΦ"; invert Ht.
    all: wp_rec; wp_pures.
    - rewrite !right_id. iSmash.
    - wp_apply (wp_wand with "(Hfn [] [HΨ])").
      { rewrite list_lookup_middle //. }
      { rewrite take_app //. }
      clear acc. iIntros "%acc HΨ".
      rewrite Z.add_1_l -Nat2Z.inj_succ.
      wp_apply ("IH" with "[] [] [$HΨ $Hfn //]").
      { rewrite take_app -assoc //. }
      { rewrite app_length take_length app_length. iSmash. }
      iSmash.
  Qed.
  Lemma lst_foldli_spec Ψ t vs acc fn :
    {{{
      ▷ Ψ 0 [] acc ∗
      lst_model t vs ∗
      □ (
        ∀ i v acc,
        ⌜vs !! i = Some v⌝ -∗
        Ψ i (take i vs) acc -∗
        WP fn acc #i v {{ acc,
          ▷ Ψ (S i) (take i vs ++ [v]) acc
        }}
      )
    }}}
      lst_foldli t acc fn
    {{{ acc,
      RET acc;
      Ψ (length vs) vs acc
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & #Hfn) HΦ".
    wp_rec.
    rewrite -Nat2Z.inj_0.
    wp_smart_apply (lst_foldli_aux_spec [] Ψ with "[$HΨ $Hfn //]"); [done.. |].
    iSmash.
  Qed.
  Lemma lst_foldli_spec' Ψ t vs acc fn :
    {{{
      ▷ Ψ 0 [] acc ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        ∀ acc,
        Ψ i (take i vs) acc -∗
        WP fn acc #i v {{ acc,
          ▷ Ψ (S i) (take i vs ++ [v]) acc
        }}
      )
    }}}
      lst_foldli t acc fn
    {{{ acc,
      RET acc;
      Ψ (length vs) vs acc
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & Hfn) HΦ".
    match goal with |- context [big_opL bi_sep ?Ξ' _] => set Ξ := Ξ' end.
    pose (Ψ' i vs_left acc := (
      Ψ i vs_left acc ∗
      [∗ list] j ↦ v ∈ drop i vs, Ξ (i + j) v
    )%I).
    wp_apply (lst_foldli_spec Ψ' with "[$HΨ $Ht $Hfn]"); last iSmash.
    clear acc. iIntros "!> %i %v %acc %Hlookup (HΨ & HΞ)".
    erewrite drop_S; last done.
    iDestruct "HΞ" as "(Hfn & HΞ)".
    rewrite Nat.add_0_r. setoid_rewrite Nat.add_succ_r. iSmash.
  Qed.

  Lemma lst_foldl_spec Ψ t vs acc fn :
    {{{
      ▷ Ψ 0 [] acc ∗
      lst_model t vs ∗
      □ (
        ∀ i v acc,
        ⌜vs !! i = Some v⌝ -∗
        Ψ i (take i vs) acc -∗
        WP fn acc v {{ acc,
          ▷ Ψ (S i) (take i vs ++ [v]) acc
        }}
      )
    }}}
      lst_foldl t acc fn
    {{{ acc,
      RET acc;
      Ψ (length vs) vs acc
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & #Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_foldli_spec Ψ with "[$HΨ $Ht] HΦ").
    iSmash.
  Qed.
  Lemma lst_foldl_spec' Ψ t vs acc fn :
    {{{
      ▷ Ψ 0 [] acc ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        ∀ acc,
        Ψ i (take i vs) acc -∗
        WP fn acc v {{ acc,
          ▷ Ψ (S i) (take i vs ++ [v]) acc
        }}
      )
    }}}
      lst_foldl t acc fn
    {{{ acc,
      RET acc;
      Ψ (length vs) vs acc
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_foldli_spec' Ψ with "[$HΨ $Ht Hfn] HΦ").
    iApply (big_sepL_impl with "Hfn").
    iSmash.
  Qed.

  #[local] Lemma lst_foldri_aux_spec vs_left Ψ vs t vs_right fn acc i :
    vs = vs_left ++ vs_right →
    i = length vs_left →
    {{{
      lst_model t vs_right ∗
      ▷ Ψ (length vs) acc [] ∗
      □ (
        ∀ i v acc,
        ⌜vs !! i = Some v⌝ -∗
        Ψ (S i) acc (drop (S i) vs) -∗
        WP fn #i v acc {{ acc,
          ▷ Ψ i acc (v :: drop (S i) vs)
        }}
      )
    }}}
      lst_foldri_aux t fn acc #i
    {{{ acc,
      RET acc;
      Ψ i acc vs_right
    }}}.
  Proof.
    iInduction vs_right as [| v vs_right] "IH" forall (vs_left t acc i).
    all: iIntros (->); rewrite app_length.
    all: iIntros "%Hi %Φ (%Ht & HΨ & #Hfn) HΦ"; invert Ht.
    all: wp_rec; wp_pure credit:"H£"; wp_pures.
    - rewrite Nat.add_0_r. iSmash.
    - rewrite Z.add_1_l -Nat2Z.inj_succ.
      wp_apply ("IH" with "[] [] [$HΨ $Hfn //]").
      { rewrite (assoc (++) _ [_]) //. }
      { rewrite app_length. iSmash. }
      clear acc. iIntros "%acc HΨ".
      iApply wp_fupd. wp_apply (wp_wand with "(Hfn [] [HΨ])").
      { rewrite list_lookup_middle //. }
      all: rewrite (assoc (++) _ [_]) drop_app_alt //; last (rewrite app_length /=; lia).
      clear acc. iIntros "%acc HΨ".
      iMod (lc_fupd_elim_later with "H£ HΨ") as "HΨ".
      iSmash.
  Qed.
  Lemma lst_foldri_spec Ψ t vs fn acc :
    {{{
      lst_model t vs ∗
      ▷ Ψ (length vs) acc [] ∗
      □ (
        ∀ i v acc,
        ⌜vs !! i = Some v⌝ -∗
        Ψ (S i) acc (drop (S i) vs) -∗
        WP fn #i v acc {{ acc,
          ▷ Ψ i acc (v :: drop (S i) vs)
        }}
      )
    }}}
      lst_foldri t fn acc
    {{{ acc,
      RET acc;
      Ψ 0 acc vs
    }}}.
  Proof.
    iIntros "%Φ (#Ht & HΨ & #Hfn) HΦ".
    wp_rec.
    rewrite -Nat2Z.inj_0.
    wp_smart_apply (lst_foldri_aux_spec [] Ψ with "[$Ht $HΨ $Hfn]"); [done.. |].
    iSmash.
  Qed.
  Lemma lst_foldri_spec' Ψ t vs fn acc :
    {{{
      lst_model t vs ∗
      ▷ Ψ (length vs) acc [] ∗
      ( [∗ list] i ↦ v ∈ vs,
        ∀ acc,
        Ψ (S i) acc (drop (S i) vs) -∗
        WP fn #i v acc {{ acc,
          ▷ Ψ i acc (v :: drop (S i) vs)
        }}
      )
    }}}
      lst_foldri t fn acc
    {{{ acc,
      RET acc;
      Ψ 0 acc vs
    }}}.
  Proof.
    iIntros "%Φ (#Ht & HΨ & Hfn) HΦ".
    match goal with |- context [big_opL bi_sep ?Ξ' _] => set Ξ := Ξ' end.
    pose (Ψ' i acc vs_right := (
      Ψ i acc vs_right ∗
      [∗ list] j ↦ v ∈ take i vs, Ξ j v
    )%I).
    wp_apply (lst_foldri_spec Ψ' with "[$Ht HΨ Hfn]"); last iSmash.
    iFrame. rewrite firstn_all2; last lia. iFrame.
    clear acc. iIntros "!> %i %v %acc %Hlookup (HΨ & HΞ)".
    pose proof Hlookup as Hi%lookup_lt_Some.
    erewrite take_S_r; last done.
    iDestruct "HΞ" as "(HΞ & Hfn & _)".
    rewrite Nat.add_0_r take_length Nat.min_l; last lia. iSmash.
  Qed.

  Lemma lst_foldr_spec Ψ t vs fn acc :
    {{{
      lst_model t vs ∗
      ▷ Ψ (length vs) acc [] ∗
      □ (
        ∀ i v acc,
        ⌜vs !! i = Some v⌝ -∗
        Ψ (S i) acc (drop (S i) vs) -∗
        WP fn v acc {{ acc,
          ▷ Ψ i acc (v :: drop (S i) vs)
        }}
      )
    }}}
      lst_foldr t fn acc
    {{{ acc,
      RET acc;
      Ψ 0 acc vs
    }}}.
  Proof.
    iIntros "%Φ (#Ht & HΨ & #Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_foldri_spec Ψ with "[$Ht $HΨ] HΦ").
    iSmash.
  Qed.
  Lemma lst_foldr_spec' Ψ t vs fn acc :
    {{{
      lst_model t vs ∗
      ▷ Ψ (length vs) acc [] ∗
      ( [∗ list] i ↦ v ∈ vs,
        ∀ acc,
        Ψ (S i) acc (drop (S i) vs) -∗
        WP fn v acc {{ acc,
          ▷ Ψ i acc (v :: drop (S i) vs)
        }}
      )
    }}}
      lst_foldr t fn acc
    {{{ acc,
      RET acc;
      Ψ 0 acc vs
    }}}.
  Proof.
    iIntros "%Φ (#Ht & HΨ & Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_foldri_spec' Ψ with "[$Ht $HΨ Hfn] HΦ").
    iApply (big_sepL_impl with "Hfn").
    iSmash.
  Qed.

  Lemma lst_size_spec t vs :
    {{{
      lst_model t vs
    }}}
      lst_size t
    {{{
      RET #(length vs); True
    }}}.
  Proof.
    iIntros "%Φ #Ht HΦ".
    wp_rec.
    pose Ψ i vs_left acc : iProp Σ := (
      ⌜acc = #(length vs_left)⌝
    )%I.
    wp_smart_apply (lst_foldl_spec Ψ with "[$Ht]"); last iSmash.
    iSteps. rewrite app_length. iSmash.
  Qed.

  Lemma lst_rev_spec t vs :
    {{{
      lst_model t vs
    }}}
      lst_rev t
    {{{ t',
      RET t';
      lst_model t' (reverse vs)
    }}}.
  Proof.
    iIntros "%Φ Ht HΦ".
    wp_rec.
    pose Ψ i vs' acc := (
      lst_model acc (reverse vs')
    )%I.
    wp_smart_apply (lst_foldl_spec Ψ with "[$Ht]"); last iSmash.
    iSteps. rewrite reverse_app /=. auto.
  Qed.

  Lemma lst_app_spec t1 vs1 t2 vs2 :
    {{{
      lst_model t1 vs1 ∗
      lst_model t2 vs2
    }}}
      lst_app t1 t2
    {{{ t,
      RET t;
      lst_model t (vs1 ++ vs2)
    }}}.
  Proof.
    iIntros "%Φ (#Ht1 & #Ht2) HΦ".
    wp_rec.
    pose Ψ i acc vs := (
      lst_model acc (vs ++ vs2)
    )%I.
    wp_smart_apply (lst_foldr_spec Ψ with "[$Ht1]"); last iSmash.
    iSteps; auto.
  Qed.

  Lemma lst_snoc_spec t vs v :
    {{{
      lst_model t vs
    }}}
      lst_snoc t v
    {{{ t',
      RET t';
      lst_model t' (vs ++ [v])
    }}}.
  Proof.
    iIntros "%Φ #Ht HΦ".
    wp_rec.
    wp_smart_apply (lst_singleton_spec with "[//]"). iIntros "%tv #Htv".
    wp_apply (lst_app_spec _ _ tv with "[$Ht $Htv]").
    iSmash.
  Qed.

  Lemma lst_iteri_spec Ψ t vs fn :
    {{{
      ▷ Ψ 0 [] ∗
      lst_model t vs ∗
      □ (
        ∀ i v,
        ⌜vs !! i = Some v⌝ -∗
        Ψ i (take i vs) -∗
        WP fn #i v {{ res,
          ⌜res = #()⌝ ∗
          ▷ Ψ (S i) (take i vs ++ [v])
        }}
      )
    }}}
      lst_iteri t fn
    {{{
      RET #();
      Ψ (length vs) vs
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & #Hfn) HΦ".
    wp_rec.
    pose Ψ' i vs acc := (
      ⌜acc = #()⌝ ∗
      Ψ i vs
    )%I.
    wp_smart_apply (lst_foldli_spec Ψ' with "[$HΨ $Ht]"); iSmash.
  Qed.
  Lemma lst_iteri_spec' Ψ t vs fn :
    {{{
      ▷ Ψ 0 [] ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i (take i vs) -∗
        WP fn #i v {{ res,
          ⌜res = #()⌝ ∗
          ▷ Ψ (S i) (take i vs ++ [v])
        }}
      )
    }}}
      lst_iteri t fn
    {{{
      RET #();
      Ψ (length vs) vs
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & Hfn) HΦ".
    wp_rec.
    pose Ψ' i vs acc := (
      ⌜acc = #()⌝ ∗
      Ψ i vs
    )%I.
    wp_smart_apply (lst_foldli_spec' Ψ' with "[$HΨ $Ht Hfn]"); iSteps.
    iApply (big_sepL_impl with "Hfn").
    iSmash.
  Qed.
  Lemma lst_iteri_spec_disentangled Ψ t vs fn :
    {{{
      lst_model t vs ∗
      □ (
        ∀ i v,
        ⌜vs !! i = Some v⌝ -∗
        WP fn #i v {{ res,
          ⌜res = #()⌝ ∗
          ▷ Ψ i v
        }}
      )
    }}}
      lst_iteri t fn
    {{{
      RET #();
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i v
      )
    }}}.
  Proof.
    iIntros "%Φ (#Ht & #Hfn) HΦ".
    pose (Ψ' i vs := (
      [∗ list] j ↦ v ∈ vs, Ψ j v
    )%I).
    wp_apply (lst_iteri_spec Ψ' with "[$Ht]"); last iSmash.
    rewrite /Ψ'. iSteps.
    rewrite big_sepL_snoc take_length Nat.min_l; first iSmash.
    eapply Nat.lt_le_incl, lookup_lt_Some. done.
  Qed.
  Lemma lst_iteri_spec_disentangled' Ψ t vs fn :
    {{{
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        WP fn #i v {{ res,
          ⌜res = #()⌝ ∗
          ▷ Ψ i v
        }}
      )
    }}}
      lst_iteri t fn
    {{{
      RET #();
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i v
      )
    }}}.
  Proof.
    iIntros "%Φ (#Ht & Hfn) HΦ".
    pose (Ψ' i vs := (
      [∗ list] j ↦ v ∈ vs, Ψ j v
    )%I).
    wp_apply (lst_iteri_spec' Ψ' with "[$Ht Hfn]"); last iSmash.
    rewrite /Ψ'. iSteps.
    iApply (big_sepL_impl with "Hfn"). iSteps.
    rewrite big_sepL_snoc take_length Nat.min_l; first iSmash.
    eapply Nat.lt_le_incl, lookup_lt_Some. done.
  Qed.

  Lemma lst_iter_spec Ψ t vs fn :
    {{{
      ▷ Ψ 0 [] ∗
      lst_model t vs ∗
      □ (
        ∀ i v,
        ⌜vs !! i = Some v⌝ -∗
        Ψ i (take i vs) -∗
        WP fn v {{ res,
          ⌜res = #()⌝ ∗
          ▷ Ψ (S i) (take i vs ++ [v])
        }}
      )
    }}}
      lst_iter t fn
    {{{
      RET #();
      Ψ (length vs) vs
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & #Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_iteri_spec Ψ with "[$HΨ $Ht] HΦ").
    iSmash.
  Qed.
  Lemma lst_iter_spec' Ψ t vs fn :
    {{{
      ▷ Ψ 0 [] ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i (take i vs) -∗
        WP fn v {{ res,
          ⌜res = #()⌝ ∗
          ▷ Ψ (S i) (take i vs ++ [v])
        }}
      )
    }}}
      lst_iter t fn
    {{{
      RET #();
      Ψ (length vs) vs
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_iteri_spec' Ψ with "[$HΨ $Ht Hfn] HΦ").
    iApply (big_sepL_impl with "Hfn").
    iSmash.
  Qed.
  Lemma lst_iter_spec_disentangled Ψ t vs fn :
    {{{
      lst_model t vs ∗
      □ (
        ∀ i v,
        ⌜vs !! i = Some v⌝ -∗
        WP fn v {{ res,
          ⌜res = #()⌝ ∗
          ▷ Ψ i v
        }}
      )
    }}}
      lst_iter t fn
    {{{
      RET #();
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i v
      )
    }}}.
  Proof.
    iIntros "%Φ (#Ht & #Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_iteri_spec_disentangled Ψ with "[$Ht] HΦ").
    iSmash.
  Qed.
  Lemma lst_iter_spec_disentangled' Ψ t vs fn :
    {{{
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        WP fn v {{ res,
          ⌜res = #()⌝ ∗
          ▷ Ψ i v
        }}
      )
    }}}
      lst_iter t fn
    {{{
      RET #();
      ( [∗ list] i ↦ v ∈ vs,
        Ψ i v
      )
    }}}.
  Proof.
    iIntros "%Φ (#Ht & Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_iteri_spec_disentangled' Ψ with "[$Ht Hfn] HΦ").
    iApply (big_sepL_impl with "Hfn").
    iSmash.
  Qed.

  #[local] Lemma lst_mapi_aux_spec vs_left ws_left Ψ vs t vs_right fn i :
    vs = vs_left ++ vs_right →
    i = length vs_left →
    i = length ws_left →
    {{{
      ▷ Ψ i vs_left ws_left ∗
      lst_model t vs_right ∗
      □ (
        ∀ i v ws,
        ⌜vs !! i = Some v ∧ i = length ws⌝ -∗
        Ψ i (take i vs) ws -∗
        WP fn #i v {{ w,
          ▷ Ψ (S i) (take i vs ++ [v]) (ws ++ [w])
        }}
      )
    }}}
      lst_mapi_aux t fn #i
    {{{ t' ws_right,
      RET t';
      ⌜length vs = (length ws_left + length ws_right)%nat⌝ ∗
      lst_model t' ws_right ∗
      Ψ (length vs) vs (ws_left ++ ws_right)
    }}}.
  Proof.
    iInduction vs_right as [| v vs_right] "IH" forall (vs_left ws_left t i).
    all: iIntros (->); rewrite app_length.
    all: iIntros "%Hi1 %Hi2 %Φ (HΨ & %Ht & #Hfn) HΦ"; invert Ht.
    all: wp_rec; wp_pures.
    - iApply ("HΦ" $! _ []).
      rewrite !right_id. iSmash.
    - wp_apply (wp_wand with "(Hfn [] [HΨ])").
      { rewrite list_lookup_middle //. }
      { rewrite take_app //. }
      iIntros "%w HΨ".
      wp_pures.
      rewrite Z.add_1_l -Nat2Z.inj_succ.
      wp_apply ("IH" with "[] [] [] [$HΨ $Hfn //]").
      { rewrite take_app -assoc //. }
      { rewrite app_length take_length app_length. iSmash. }
      { rewrite app_length. iSmash. }
      iIntros "%t' %ws_right (%Hvs & %Ht' & HΨ)".
      wp_pures.
      iApply ("HΦ" $! _ (w :: ws_right)).
      rewrite -!assoc. rewrite app_length /= in Hvs. iSteps. auto.
  Qed.
  Lemma lst_mapi_spec Ψ t vs fn :
    {{{
      ▷ Ψ 0 [] [] ∗
      lst_model t vs ∗
      □ (
        ∀ i v ws,
        ⌜vs !! i = Some v ∧ i = length ws⌝ -∗
        Ψ i (take i vs) ws -∗
        WP fn #i v {{ w,
          ▷ Ψ (S i) (take i vs ++ [v]) (ws ++ [w])
        }}
      )
    }}}
      lst_mapi t fn
    {{{ t' ws,
      RET t';
      ⌜length vs = length ws⌝ ∗
      lst_model t' ws ∗
      Ψ (length vs) vs ws
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & #Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_mapi_aux_spec [] [] Ψ with "[$HΨ $Ht $Hfn]"); [done.. |].
    iSmash.
  Qed.
  Lemma lst_mapi_spec' Ψ t vs fn :
    {{{
      ▷ Ψ 0 [] [] ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        ∀ ws,
        ⌜i = length ws⌝ -∗
        Ψ i (take i vs) ws -∗
        WP fn #i v {{ w,
          ▷ Ψ (S i) (take i vs ++ [v]) (ws ++ [w])
        }}
      )
    }}}
      lst_mapi t fn
    {{{ t' ws,
      RET t';
      ⌜length vs = length ws⌝ ∗
      lst_model t' ws ∗
      Ψ (length vs) vs ws
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & Hfn) HΦ".
    match goal with |- context [big_opL bi_sep ?Ξ' _] => set Ξ := Ξ' end.
    pose (Ψ' i vs_left ws := (
      Ψ i vs_left ws ∗
      [∗ list] j ↦ v ∈ drop i vs, Ξ (i + j) v
    )%I).
    wp_apply (lst_mapi_spec Ψ' with "[$HΨ $Ht $Hfn]"); last iSmash.
    iIntros "!> %i %v %ws (%Hlookup & %Hi) (HΨ & HΞ)".
    erewrite drop_S; last done.
    iDestruct "HΞ" as "(Hfn & HΞ)".
    rewrite Nat.add_0_r. setoid_rewrite Nat.add_succ_r. iSmash.
  Qed.
  Lemma lst_mapi_spec_disentangled Ψ t vs fn :
    {{{
      lst_model t vs ∗
      □ (
        ∀ i v,
        ⌜vs !! i = Some v⌝ -∗
        WP fn #i v {{ w,
          ▷ Ψ i v w
        }}
      )
    }}}
      lst_mapi t fn
    {{{ t' ws,
      RET t';
      ⌜length vs = length ws⌝ ∗
      lst_model t' ws ∗
      ( [∗ list] i ↦ v; w ∈ vs; ws,
        Ψ i v w
      )
    }}}.
  Proof.
    iIntros "%Φ (#Ht & #Hfn) HΦ".
    pose Ψ' i vs_left ws := (
      [∗ list] j ↦ v; w ∈ vs_left; ws, Ψ j v w
    )%I.
    wp_apply (lst_mapi_spec Ψ' with "[$Ht]"); last iSmash.
    rewrite /Ψ'. iSteps.
    rewrite big_sepL2_snoc take_length Nat.min_l; first iSmash.
    eapply Nat.lt_le_incl, lookup_lt_Some. done.
  Qed.
  Lemma lst_mapi_spec_disentangled' Ψ t vs fn :
    {{{
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        WP fn #i v {{ w,
          ▷ Ψ i v w
        }}
      )
    }}}
      lst_mapi t fn
    {{{ t' ws,
      RET t';
      ⌜length vs = length ws⌝ ∗
      lst_model t' ws ∗
      ( [∗ list] i ↦ v; w ∈ vs; ws,
        Ψ i v w
      )
    }}}.
  Proof.
    iIntros "%Φ (#Ht & Hfn) HΦ".
    pose Ψ' i vs_left ws := (
      [∗ list] j ↦ v; w ∈ vs_left; ws, Ψ j v w
    )%I.
    wp_apply (lst_mapi_spec' Ψ' with "[$Ht Hfn]"); last iSmash.
    rewrite /Ψ'. iSteps.
    iApply (big_sepL_impl with "Hfn"). iSteps.
    rewrite big_sepL2_snoc take_length Nat.min_l; first iSmash.
    eapply Nat.lt_le_incl, lookup_lt_Some. done.
  Qed.

  Lemma lst_map_spec Ψ t vs fn :
    {{{
      ▷ Ψ 0 [] [] ∗
      lst_model t vs ∗
      □ (
        ∀ i v ws,
        ⌜vs !! i = Some v ∧ i = length ws⌝ -∗
        Ψ i (take i vs) ws -∗
        WP fn v {{ w,
          ▷ Ψ (S i) (take i vs ++ [v]) (ws ++ [w])
        }}
      )
    }}}
      lst_map t fn
    {{{ t' ws,
      RET t';
      ⌜length vs = length ws⌝ ∗
      lst_model t' ws ∗
      Ψ (length vs) vs ws
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & #Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_mapi_spec Ψ with "[$HΨ $Ht] HΦ").
    iSmash.
  Qed.
  Lemma lst_map_spec' Ψ t vs fn :
    {{{
      ▷ Ψ 0 [] [] ∗
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        ∀ ws,
        ⌜i = length ws⌝ -∗
        Ψ i (take i vs) ws -∗
        WP fn v {{ w,
          ▷ Ψ (S i) (take i vs ++ [v]) (ws ++ [w])
        }}
      )
    }}}
      lst_map t fn
    {{{ t' ws,
      RET t';
      ⌜length vs = length ws⌝ ∗
      lst_model t' ws ∗
      Ψ (length vs) vs ws
    }}}.
  Proof.
    iIntros "%Φ (HΨ & #Ht & Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_mapi_spec' Ψ with "[$HΨ $Ht Hfn] HΦ").
    iApply (big_sepL_impl with "Hfn").
    iSmash.
  Qed.
  Lemma lst_map_spec_disentangled Ψ t vs fn :
    {{{
      lst_model t vs ∗
      □ (
        ∀ i v,
        ⌜vs !! i = Some v⌝ -∗
        WP fn v {{ w,
          ▷ Ψ i v w
        }}
      )
    }}}
      lst_map t fn
    {{{ t' ws,
      RET t';
      ⌜length vs = length ws⌝ ∗
      lst_model t' ws ∗
      ( [∗ list] i ↦ v; w ∈ vs; ws,
        Ψ i v w
      )
    }}}.
  Proof.
    iIntros "%Φ (#Ht & #Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_mapi_spec_disentangled Ψ with "[$Ht] HΦ").
    iSmash.
  Qed.
  Lemma lst_map_spec_disentangled' Ψ t vs fn :
    {{{
      lst_model t vs ∗
      ( [∗ list] i ↦ v ∈ vs,
        WP fn v {{ w,
          ▷ Ψ i v w
        }}
      )
    }}}
      lst_map t fn
    {{{ t' ws,
      RET t';
      ⌜length vs = length ws⌝ ∗
      lst_model t' ws ∗
      ( [∗ list] i ↦ v; w ∈ vs; ws,
        Ψ i v w
      )
    }}}.
  Proof.
    iIntros "%Φ (#Ht & Hfn) HΦ".
    wp_rec.
    wp_smart_apply (lst_mapi_spec_disentangled' Ψ with "[$Ht Hfn] HΦ").
    iApply (big_sepL_impl with "Hfn").
    iSmash.
  Qed.
End heap_GS.

#[global] Opaque lst_cons.
#[global] Opaque lst_singleton.
#[global] Opaque lst_head.
#[global] Opaque lst_tail.
#[global] Opaque lst_is_empty.
#[global] Opaque lst_get.
#[global] Opaque lst_initi.
#[global] Opaque lst_init.
#[global] Opaque lst_foldli.
#[global] Opaque lst_foldl.
#[global] Opaque lst_foldri.
#[global] Opaque lst_foldr.
#[global] Opaque lst_size.
#[global] Opaque lst_rev.
#[global] Opaque lst_app.
#[global] Opaque lst_snoc.
#[global] Opaque lst_iteri.
#[global] Opaque lst_iter.
#[global] Opaque lst_mapi.
#[global] Opaque lst_map.

#[global] Opaque lst_model.