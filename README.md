# CollectAs

[![Build Status](https://github.com/JuliaCollections/CollectAs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaCollections/CollectAs.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaCollections/CollectAs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaCollections/CollectAs.jl)
[![Package version](https://juliahub.com/docs/General/CollectAs/stable/version.svg)](https://juliahub.com/ui/Packages/General/CollectAs)
[![Package dependencies](https://juliahub.com/docs/General/CollectAs/stable/deps.svg)](https://juliahub.com/ui/Packages/General/CollectAs?t=2)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CollectAs.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CollectAs.html)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

A Julia package to collect the elements of a given collection into a collection of the given type. Generalization of two-arg `collect`.

The package exports the name `collect_as`, see its doc string for more information.

## Behavioral difference with `collect`

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
