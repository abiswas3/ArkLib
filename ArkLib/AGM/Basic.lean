/-
Copyright (c) 2025 ArkLib Contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Quang Dao
-/

import VCVio
import Mathlib.RingTheory.Polynomial.Basic
import Mathlib.Algebra.Polynomial.FieldDivision
import Mathlib.LinearAlgebra.BilinearForm.Properties
import Mathlib.GroupTheory.SpecificGroups.Cyclic

/-! # The Algebraic Group Model (With Oblivious Sampling)

We attempt to define the algebraic group model. Our mechanization follows recent papers of Jaeger &
 Mohan [JM24](https://link.springer.com/content/pdf/10.1007/978-3-031-68388-6_2) and Lipmaa,
 Parisella, and Siim [LPS24](https://eprint.iacr.org/2024/994.pdf). -/

class IsPrimeOrderWith (G : Type*) [Group G] (p : ℕ) [Fact (Nat.Prime p)] where
  hCard : Nat.card G = p

class IsPrimeOrder (G : Type*) [Group G] where
  -- hCard : ∃p, Nat.Prime p ∧ IsPrimeOrderWith G p
  hCard : ∃ p, Fact (Nat.Prime p) ∧ Nat.card G = p

section primeGp

variable {p : Nat} [hp : Fact (Nat.Prime p)]

variable {G : Type*} [hcg : CommGroup G] [hpG : IsPrimeOrder G]

instance primeOrderIsCyclic : IsCyclic G where
  exists_zpow_surjective := by {
    rcases hpG.hCard with ⟨P, hP⟩
    have hpg : Nat.card G = P := by {
      exact hP.2
    }
    have hPP : Fact (Nat.Prime P) := by {
      exact hP.1
    }
    apply (isCyclic_of_prime_card hpg).exists_zpow_surjective
  }


instance primeOrderIsCommutative : CommGroup G where 
  mul_comm := by {
    intro a b
    rcases exists_zpow_surjective G with ⟨g, hf⟩
    have ha : ∃ x : ℤ, g^x = a := by {
      apply hf
    }
    have hb : ∃ y : ℤ, g^y = b := by {
      apply hf
    }
    rcases ha with ⟨X, hX⟩
    rcases hb with ⟨Y, hY⟩
    rw [←hX, ←hY]
    group
  }

end primeGp

-- instance : Additive G ≃+ ZMod p := sorry

open Polynomial

section AGM

/-- A type is **serializable** if it can be encoded and decoded to a bit string.

This is highly similar but inequivalent to other type classes like `ToString` or `Repr`.

A special case of `Encodable` except that we require all encodings have the same bit-length, and do
not require decoding. -/
class Serializable (α : Type*) where
  len : ℕ
  toBitVec : α → BitVec len

/-- A type is **deserializable** if it can be decoded from a bit string of a given length. -/
class Deserializable (α : Type*) where
  len : ℕ
  fromBitVec : BitVec len → Option α

-- #check LinearMap.mk₂'

-- #check LinearMap.BilinForm.linMulLin

-- #check isCyclic_of_prime_card

-- These imply a finite cyclic group of prime order `p`
variable {G : Type*} [Group G] {p : ℕ} [Fact (Nat.Prime p)] (h : Nat.card G = p)

@[ext]
structure GroupRepresentation (prev : List G) (target : G) where
  exponents : List (ZMod p)
  hEq : (prev.zipWith (fun g a => g ^ a.val) exponents).prod = target

-- #print GroupRepresentation

/-- An adversary in the Algebraic Group Model (AGM) may only access group elements via handles.

To formalize this, we let the handles be natural numbers, and assume that they are indices into an
(infinite) array storing potential group elements. -/
def GroupValTable (G : Type*) := Nat → Option G

local instance {α : Type*} : Zero (Option α) where
  zero := none

-- This might be a better abstraction since the type is finite
-- We put `DFinsupp` since it's computable, not sure if really needed (if not we use `Finsupp`)
def GroupVal (G : Type*) := Π₀ _ : Nat, Option G

-- This allows an adversary to perform the group operation on group elements stored at the indices
-- `i` and `j` (if they are both defined), storing the result at index `k`.
def GroupOpOracle : OracleSpec Unit := fun _ => (Nat × Nat × Nat, Unit)

/-- This oracle interface allows an adversary to get the bit encoding of a group element. -/
def GroupEncodeOracle (bitLength : ℕ) : OracleSpec Unit := fun _ => (Nat, BitVec bitLength)

/-- This oracle interface allows an adversary to get the bit encoding of a group element. -/
def GroupDecodeOracle (bitLength : ℕ) (G : Type) : OracleSpec Unit :=
  fun _ => (BitVec bitLength, Option G)

/-- An adversary in the Algebraic Group Model (AGM), given a single group `G` with elements having
    representation size `bitLength`, is a stateful oracle computation with oracle access to the
    `GroupOp` and `GroupEncode` oracles, and the state being the array of group elements (accessed
    via handles).

  How to make the adversary truly independent of the group description? It could have had `G`
  hardwired. Perhaps we need to enforce parametricity, i.e. it should be of type
  `∀ G, Group G → AGMAdversary G bitLength α`? -/
def AGMAdversary (G : Type) (bitLength : ℕ) : Type → Type _ := fun α => StateT (GroupVal G)
  (OracleComp ((GroupEncodeOracle bitLength) ++ₒ (GroupDecodeOracle bitLength G))) α

end AGM

namespace KZG

/-! ## The KZG Polynomial Commitment Scheme -/

-- TODO: figure out how to get `CommGroup` for free
variable {G : Type*} [CommGroup G] {p : ℕ} [hp : Fact (Nat.Prime p)] (hpG : Nat.card G = p)
  {g : G}

instance {α : Type} [CommGroup α] : AddCommMonoid (Additive α) := inferInstance

variable {G₁ : Type*} [hG1 : CommGroup G₁] [hpG1 : IsPrimeOrderWith G₁ p] {g₁ : G₁}
  {G₂ : Type*} [hG2 : CommGroup G₂] [hpG2 : IsPrimeOrderWith G₂ p] {g₂ : G₂}
  {Gₜ : Type*} [CommGroup Gₜ] [IsPrimeOrderWith Gₜ p]
  -- TODO: need to make this a `ZMod p`-linear map
  (pairing : (Additive G₁) →ₗ[ℤ] (Additive G₂) →ₗ[ℤ] (Additive Gₜ))

-- instance : IsCyclic G := isCyclic_of_prime_card h

-- #check unique_of_prime_card

/-- The vector of length `n + 1` that consists of powers:
  `#v[1, g, g ^ a.val, g ^ (a.val ^ 2), ..., g ^ (a.val ^ n)` -/
def towerOfExponents (g : G) (a : ZMod p) (n : ℕ) : Vector G (n + 1) :=
  .ofFn (fun i => g ^ (a.val ^ i.val))

variable {n : ℕ}

/-- The `srs` (structured reference string) for the KZG commitment scheme with secret exponent `a`
    is defined as `#v[g₁, g₁ ^ a, g₁ ^ (a ^ 2), ..., g₁ ^ (a ^ (n - 1))], #v[g₂, g₂ ^ a]` -/
def generateSrs (n : ℕ) (a : ZMod p) : Vector G₁ (n + 1) × Vector G₂ 2 :=
  (towerOfExponents g₁ a n, towerOfExponents g₂ a 1)

/-- One can verify that the `srs` is valid via using the pairing -/
def checkSrs (proveSrs : Vector G₁ (n + 1)) (verifySrs : Vector G₂ 2) : Prop :=
  ∀ i : Fin n,
    pairing (proveSrs[i.succ]) (verifySrs[0]) = pairing (proveSrs[i.castSucc]) (verifySrs[1])

/-- To commit to an `n`-tuple of coefficients `coeffs` (corresponding to a polynomial of degree less
    than `n`), we compute: `∏ i : Fin n, srs[i] ^ (p.coeff i)` -/
def commit (srs : Vector G₁ n) (coeffs : Fin n → ZMod p) : G₁ :=
  ∏ i : Fin n, srs[i] ^ (coeffs i).val

/-- When committing `coeffs` using `srs` generated by `towerOfExponents`, and `coeffs` correspond to
  a polynomial `poly : (ZMod p)[X]` of degree `< n + 1`, we get the result `g₁ ^ (p.eval a).val` -/

-- What follows is super messy; still in process of cleaning up...

@[simp]
theorem zpow_eq_iff_zpow_intCast_eq {g : G₁} (a b : ℕ) : g^a = g^b ↔ g^(a : ℤ) = g^(b : ℤ) := by
  simp

theorem commit_eq {g : G₁} {a : ZMod p} (poly : degreeLT (ZMod p) (n + 1)) :
    commit (towerOfExponents g a n) (degreeLTEquiv _ _ poly) = g ^ (poly.1.eval a).val := by
  simp [commit, towerOfExponents]
  simp_rw [← pow_mul, Finset.prod_pow_eq_pow_sum]
  rw [
      eval_eq_sum_degreeLTEquiv poly.property, 
      zpow_eq_iff_zpow_intCast_eq, 
      ←orderOf_dvd_sub_iff_zpow_eq_zpow
     ]
  have hordg : g = 1 ∨ orderOf g = p := by
    have ord_g_dvd : orderOf g ∣ p := by rw [←hpG1.hCard]; apply orderOf_dvd_natCard
    rw [Nat.dvd_prime, orderOf_eq_one_iff] at ord_g_dvd
    exact ord_g_dvd
    exact hp.out
    
  rcases hordg with ord1|ordp
  · rw [ord1]
    simp
  · rw [ordp]
    simp
    rw [←ZMod.intCast_eq_intCast_iff_dvd_sub]
    simp
    apply Fintype.sum_congr
    intro x
    group

-- if this is already in mathlib4 somewhere, I couldn't find it. for
-- an exercise I did it by hand, albeit in a haphazard way

instance Field (p : ℕ) [hp : Fact (Nat.Prime p)]: Field (ZMod p) where
  inv := fun n => if n = 0 then 0 else ZMod.inv p n
  inv_zero := by simp
  nnqsmul := _ --fun q n => q.num*n * (q.den : (ZMod p))⁻¹
  qsmul := _ --fun q n => q.num*n * (q.den : (ZMod p))⁻¹
  mul_inv_cancel := by
    intro a ha
    simp [ha]
    have hcoprime : ((a.val).Coprime p) := by
      unfold Nat.Coprime
      have hap1 : a.val.gcd p ∣ p := by 
        exact (Nat.gcd_dvd a.val p).2
      rw [Nat.dvd_prime hp.out] at hap1
      rcases hap1 with gcd1|gcdp
      · exact gcd1
      · have hap2 : a.val.gcd p ∣ a.val := by 
          exact (Nat.gcd_dvd a.val p).1
        rw [gcdp] at hap2
        have hap3 : a.val < p := by exact ZMod.val_lt a
        have hap4 : a.val = 0 := by exact Nat.eq_zero_of_dvd_of_lt hap2 hap3
        have hap5 : a = 0 := by exact (ZMod.val_eq_zero a).mp hap4
        contradiction  
    rw [←ZMod.coe_mul_inv_eq_one a.val hcoprime]
    congr
    · simp
    · simp

theorem sub_degree_le {R : Type} [CommRing R] (p q : Polynomial R) : (p - q).degree ≤ max p.degree q.degree := by exact degree_sub_le p q

theorem degreeLT_is_degree_lt {R : Type} [CommRing R] {n : Nat} (f : degreeLT R n) : f.val.degree < n := by apply?

-- this is in the middle of working; very sloppy currently

/-- To generate an opening proving that a polynomial `poly` has a certain evaluation at `z`,
  we return the commitment to the polynomial `q(X) = (poly(X) - poly.eval z) / (X - z)` -/
noncomputable def generateOpening [Fact (Nat.Prime p)] (srs : Vector G₁ (n + 1))
    (coeffs : Fin (n + 1) → ZMod p) (hc : ∃ x : Fin (n+1), coeffs x ≠ 0) (z : ZMod p) : G₁ :=
  letI poly : degreeLT (ZMod p) (n + 1) := (degreeLTEquiv (ZMod p) (n + 1)).invFun coeffs
  letI q_poly : (X - C z) ∣ (poly.val - C (poly.val.eval z)) := by exact X_sub_C_dvd_sub_C_eval
  --have hcc : poly != 0 := by sorry
  letI q : degreeLT (ZMod p) (n + 1) :=
    ⟨Polynomial.div (poly.val - C (poly.val.eval z)) (X - C z), by
      apply mem_degreeLT.mpr
      have hPoly : (Polynomial.div (poly.val - C (poly.val.eval z)) (X - C z)).degree 
        ≤ (poly.val - C (poly.val.eval z)).degree := by {
        apply Polynomial.degree_div_le (poly.val - C (poly.val.eval z)) (X - C z)
        --apply Polynomial.degree_div_le hcc (by simp)
      }

      have hPoly3 : (poly.val - C (poly.val.eval z)).degree ≤ max poly.val.degree (C (poly.val.eval z)).degree := by {
        apply degree_sub_le poly.val (C (poly.val.eval z))
      }
      have hd1 : poly.val.degree <  WithBot.some (n+1) := by 
        sorry
        --rw [←Polynomial.mem_degreeLT]
        
        
      have hPoly2 : (poly.val - C (poly.val.eval z)).degree < n+1 := by {
        
        #check poly.val
        #check (poly.val - C (poly.val.eval z)).degree
        
        sorry
        --apply?
      }
      
      have h3 : WithBot.some (n+1) = (WithBot.some n)+1 := by simp
      
      simp [h3]
      exact lt_of_le_of_lt hPoly hPoly2
      ⟩

      --Polynomial.degree_div_le hcc (by simp)
      -- Don't know why `degree_div_le` time out here
      -- refine lt_of_le_of_lt (degree_div_le _ (X - C z)) ?_
      -- refine lt_of_le_of_lt (degree_sub_le _ _) (sup_lt_iff.mpr ?_)
      -- constructor
      -- · exact mem_degreeLT.mp poly.property
      -- · exact lt_of_lt_of_le degree_C_lt (by norm_cast; omega)⟩
  commit srs (degreeLTEquiv (ZMod p) (n + 1) q)

/-- To verify a KZG opening `opening` for a commitment `commitment` at point `z` with claimed
  evaluation `v`, we use the pairing to check "in the exponent" that `p(a) - p(z) = q(a) * (a - z)`,
  where `p` is the polynomial and `q` is the quotient of `p` at `z` -/
noncomputable def verifyOpening (verifySrs : Vector G₂ 2) (commitment : G₁) (opening : G₁)
    (z : ZMod p) (v : ZMod p) : Prop :=
  pairing (commitment / g₁ ^ v.val) (verifySrs[0]) = pairing opening (verifySrs[1] / g₂ ^ z.val)

-- p(a) - p(z) = q(a) * (a - z)
-- e ( C / g₁ ^ v , g₂ ) = e ( O , g₂ ^ a / g₂ ^ z)

-- theorem correctness {g : G} {a : ZMod p} {coeffs : Fin n → ZMod p} {z : ZMod p} :

end KZG
