# CollectAs

[![Build Status](https://github.com/JuliaCollections/CollectAs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaCollections/CollectAs.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaCollections/CollectAs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaCollections/CollectAs.jl)
[![Package version](https://juliahub.com/docs/General/CollectAs/stable/version.svg)](https://juliahub.com/ui/Packages/General/CollectAs)
[![Package dependencies](https://juliahub.com/docs/General/CollectAs/stable/deps.svg)](https://juliahub.com/ui/Packages/General/CollectAs?t=2)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CollectAs.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CollectAs.html)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

A Julia package to collect the elements of a given collection into a collection of the given type. Generalization of two-arg `collect`.

The package exports the name `collect_as`, see its doc string for more information.

## Differences in behavior compared to `collect`

There is one difference in behavior between `collect` and `collect_as`: when the user doesn't provide an element type and the collection is empty, `collect` relies on type inference to determine the desired element type. The `collect_as` function is supposed to never rely on type inference, instead the behavior in this case is specified like so:

* If `eltype(collection)` is concrete, use it as the element type.

* Otherwise, `Union{}` (the bottom type, uninhabited and subtyping each type) is taken as the element type.

## Implementations

This package implements `collect_as` for some `Base` types, including:

* `Set`

* `Array`

* `Memory` (when present, on Julia v1.11 and up)

* `Tuple`

Third-party packages are invited to add CollectAs as a weak dependency and implement `collect_as` for their types in a package extension. Some example packages that implement `collect_as` for types they own:

* [FixedSizeArrays.jl](https://github.com/JuliaArrays/FixedSizeArrays.jl)

## Rough specification

### Identity

If `collection isa output_type` already, a copy of `collection` is returned.

### Return type

The following must hold for each `output_type` and `iterator` where `collect_as(output_type, iterator)` returns:

```julia
collect_as(output_type, iterator) isa output_type
```

### Element type of the output

The element type must be consistent with `output_type` (as alredy implied above).

If the output element type does not supertype the element type of `collection`, the elements of `collection` are converted into the output element type.

Rule for determining the element type of the output (when applicable, that is, when the output type depends on its element type, and the output type does not subtype `Tuple`):

* If the element type is specified by `output_type`, it's the element type of the output.

* Otherwise, if `collection` is empty:

    * If `isconcretetype(eltype(iterator))`, `eltype(iterator)` is the output element type.

    * Otherwise, `Union{}` is the output element type.

* Otherwise, the output element type is the `typejoin` of the types of the elements of `collection`.

### Shape of the output

The shape of the output must be consistent with `output_type` (as alredy implied above).

To the extent that the shape is not specified by `output_type`, it is inferred from `Base.IteratorSize(collection)`.

### Other rules for implementers to follow

Any added method must take exactly two arguments.

* If you disagree, open a feature request on Github to achieve agreement for adding to the interface.

The first argument of any added method must be constrained to be a type (of type `Type`).

Make sure you own the constraint that is placed on the first argument. This is required even when you know you own the second argument.

* The rationale for this rule is to prevent causing ambiguity for other packages.

* For example, defining a method with a signature like here is *not* allowed, because you don't own `Vector`, even if you do own `A`:

  ```julia
  function CollectAs.collect_as(::Type{Vector}, ::A) end
  ```
