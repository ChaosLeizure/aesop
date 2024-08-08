import Lake

open Lake DSL

package aesop {
  precompileModules := false -- breaks mathlib cache
}

@[default_target]
lean_lib Aesop

lean_lib AesopTest {
  globs := #[.submodules "AesopTest"]
}

require std from git "https://github.com/ChaosLeizure/batteries" @ "96b85b928b6a81e3f92f4e5f9f4487db9fc56dbc"
