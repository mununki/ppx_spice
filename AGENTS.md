# AGENTS.md

This document provides guidelines for AI coding agents working on the ppx_spice project.

## Project Overview

ppx_spice is a ReScript PPX that generates JSON (de)serializers. It is written in OCaml
and uses ppxlib for AST manipulation. The PPX processes ReScript type definitions annotated
with `@spice` and generates corresponding `_encode` and `_decode` functions.

## Build Commands

All OCaml build commands must be run from the `src/` directory:

```bash
# Navigate to source directory
cd src

# Create opam switch (first time setup)
opam switch create spice 4.14.0

# Install dependencies
opam install . --deps-only

# Build the PPX
dune build

# Build with static linking (for releases)
dune build --profile static

# Clean build artifacts
dune clean
```

## Test Commands

Tests are written in ReScript and located in the `test/` directory:

```bash
# Navigate to test directory
cd test

# Install dependencies
pnpm install

# Build ReScript code
pnpm res:build

# Clean and rebuild
pnpm res:clean && pnpm res:build

# Run all tests
pnpm test

# Run tests in watch mode
pnpm test:watch

# Run a single test file
pta './test/__tests__/spec/<test_name>_test.mjs' | tap-difflet

# Example: Run only records tests
pta './test/__tests__/spec/records_test.mjs' | tap-difflet
```

### Development Workflow

1. Make changes to OCaml code in `src/ppx/`
2. Run `dune build` in `src/`
3. Navigate to `test/` and run `pnpm res:clean && pnpm res:build`
4. Run `pnpm test` to verify changes

## Project Structure

```
ppx_spice/
├── src/ppx/                  # OCaml PPX implementation
│   ├── ppx_spice.ml          # Entry point, registers transformation
│   ├── codecs.ml             # Primitive type codec generation
│   ├── records.ml            # Record encoder/decoder generation
│   ├── variants.ml           # Variant type handling
│   ├── polyvariants.ml       # Polymorphic variant handling
│   ├── structure.ml          # Implementation (.ml) processing
│   ├── signature.ml          # Interface (.mli) processing
│   └── utils.ml              # Shared utilities
├── src/bin/bin.ml            # Executable entry point
├── test/src/                 # ReScript test source types
└── test/test/__tests__/      # Test specifications
```

### PPX Integration (rescript.json)
```json
{
  "ppx-flags": ["@mununki/ppx-spice/ppx"],
  "warnings": { "error": true, "number": "-48" }
}
```

## Code Style Guidelines

### OCaml Code Style

#### Formatting
- Use 2 spaces for indentation
- Use LF line endings
- Insert final newline at end of files
- Maximum line length: ~100 characters (soft limit)

#### Imports
Always open modules in this order at the top of each file:
```ocaml
open Ppxlib
open Parsetree
open Ast_helper
open Utils  (* Local utilities last *)
```

#### Type Definitions
- Define types at the top of the module, after opens
- Use record types for complex data structures:
```ocaml
type parsed_decl = {
  name : string;
  key : expression;
  field : expression;
  codecs : expression option * expression option;
}
```

#### Naming Conventions
- Module names: PascalCase (`Records`, `Variants`, `Polyvariants`)
- Function names: snake_case (`generate_encoder`, `parse_decl`)
- Type names: snake_case (`parsed_decl`, `generator_settings`)
- Variables: snake_case (`type_name`, `param_names`)
- Constants/suffixes: snake_case with descriptive names
  - `encoder_func_suffix = "_encode"`
  - `decoder_func_suffix = "_decode"`

#### Error Handling
- Use `Result` type for operations that can fail
- Use `fail` function from `Utils` to raise location-aware errors:
```ocaml
let fail loc message = Location.raise_errorf ~loc "%s" message

(* Usage *)
| Ptyp_any -> fail ptyp_loc "Can't generate codecs for `any` type"
```

#### Pattern Matching
- Prefer exhaustive pattern matching
- Use `_` prefix for intentionally unused variables
- Group related cases together:
```ocaml
match ptype_kind with
| Ptype_abstract -> (* handle abstract *)
| Ptype_variant decls -> (* handle variant *)
| Ptype_record decls -> (* handle record *)
| _ -> fail ptype_loc "This type is not handled by spice"
```

#### PPX-Specific Patterns
- Use ppxlib metaquot for AST construction: `[%expr ...]`, `[%pat? ...]`, `[%type: ...]`
- Always attach `res.arity` attribute for ReScript function compatibility
- Use `Utils.expr_func ~arity:1` for single-argument functions

### ReScript Test Code Style

#### Test Structure
```rescript
open Zora

zoraBlock("descriptive test block name", t => {
  // Setup
  let sampleJson = ...
  let expected = ...

  // Execute
  let result = SomeModule.function(input)

  // Assert
  t->test("assertion description", async t => {
    t->equal(result, expected, "message")
  })
})
```

#### Naming
- Test files: `<module>_test.res` (e.g., `records_test.res`)
- Test blocks: Descriptive phrases in quotes

## Dependencies

### OCaml Dependencies (from opam)
- `ocaml` >= 4.14.0, <= 4.14.2
- `dune` >= 2.8
- `ppxlib` = 0.28.0

### ReScript Dependencies (test only)
- `rescript` ^12.0.0
- `@dusty-phillips/rescript-zora` ^4.0.0

## Common Patterns

### Generated Function Names
The PPX generates functions with these naming patterns:
- Encoder: `<type_name>_encode`
- Decoder: `<type_name>_decode`

### Attribute Handling
```ocaml
(* Check for attribute *)
match get_attribute_by_name attributes "spice.key" with
| Ok (Some attr) -> (* attribute present *)
| Ok None -> (* attribute absent *)
| Error s -> fail loc s
```

### Codec Generation Flow
1. `ppx_spice.ml` registers the transformation
2. `structure.ml` / `signature.ml` process type declarations
3. `codecs.ml` handles primitive types
4. `records.ml`, `variants.ml`, `polyvariants.ml` handle complex types
5. Generated AST is returned to the compiler

## CI/CD

GitHub Actions workflows are in `.github/workflows/`:
- `build_linux.yml` - Linux x64 and arm64 builds with Alpine container
- `build_macos.yml` - macOS build
- `build_windows.yml` - Windows build
- `publish.yml` - NPM package publishing

Builds use OCaml 4.14.2 with static linking for portable binaries.
