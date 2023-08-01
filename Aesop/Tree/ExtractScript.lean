/-
Copyright (c) 2022 Jannis Limperg. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jannis Limperg
-/

import Aesop.Tracing
import Aesop.Tree.Traversal

open Lean
open Lean.Meta
open Lean.Parser.Tactic (tacticSeq)

namespace Aesop

abbrev ExtractScriptM := StateRefT UnstructuredScript MetaM

mutual
  partial def MVarClusterRef.extractScriptCore (cref : MVarClusterRef) :
      ExtractScriptM Unit := do
    let c ← cref.get
    let (some gref) ← c.provenGoal? | throwError
      m!"the mvar cluster with goals {(← c.goals.mapM (·.get)).map (·.id)} does not contain a proven goal"
    gref.extractScriptCore

  partial def GoalRef.extractScriptCore (gref : GoalRef) : ExtractScriptM Unit := do
    let g ← gref.get
    match g.normalizationState with
    | .notNormal => throwError "expected goal {g.id} to be normalised"
    | .provenByNormalization _ normScript? =>
      modify (· ++ (← getNormScript g.id normScript?))
    | .normal _ _ normScript? =>
      modify (· ++ (← getNormScript g.id normScript?))
      let (some rref) ← g.firstProvenRapp? | throwError
        m!"goal {g.id} does not have a proven rapp"
      rref.extractScriptCore g.currentGoal
    where
      @[inline, always_inline]
      getNormScript (gid : GoalId) :
          Except DisplayRuleName UnstructuredScript → ExtractScriptM UnstructuredScript
        | .ok script => pure script
        | .error rule => throwError "normalization rule {rule} (at goal {gid}) does not support tactic script generation"

  partial def RappRef.extractScriptCore (rref : RappRef) (inGoal : MVarId) : ExtractScriptM Unit := do
    let r ← rref.get
    let (some scriptBuilder) := r.scriptBuilder?
      | throwError "rule {r.appliedRule.name} (at rapp {r.id}) does not support tactic script generation"
    let tacticSeq ←
      try
        r.metaState.runMetaM' scriptBuilder.unstructured.run
      catch e =>
        throwError "script builder for rapp {r.id} reported error:{indentD $ e.toMessageData}"
    let otherSolvedGoals := r.assignedMVars.toArray
    let outGoals ← r.foldSubgoalsM (init := #[]) λ outGoals gref => do
      let g ← gref.get
      return outGoals.push
        { goal := g.preNormGoal, mvars := .ofArray g.mvars.toArray }
    modify λ s => s.push { tacticSeq, inGoal, outGoals, otherSolvedGoals }
    r.children.forM (·.extractScriptCore)
end

@[inline]
def MVarClusterRef.extractScript (cref : MVarClusterRef) :
    MetaM UnstructuredScript := do
  let result ← (·.snd) <$> cref.extractScriptCore.run #[]
  return result

end Aesop
