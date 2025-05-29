# Collects

[![Build Status](https://github.com/JuliaCollections/Collects.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaCollections/Collects.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaCollections/Collects.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaCollections/Collects.jl)
[![Package version](https://juliahub.com/docs/General/Collects/stable/version.svg)](https://juliahub.com/ui/Packages/General/Collects)
[![Package dependencies](https://juliahub.com/docs/General/Collects/stable/deps.svg)](https://juliahub.com/ui/Packages/General/Collects?t=2)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/Collects.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/Collects.html)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

A Julia package to collect the elements of a given collection into a collection of the given type. Generalizes the `collect` function from `Base`.

Exports:

* `Collect`, a type

* `EmptyIteratorHandling`, a module

## Motivation

The motivation for creating this package is overcoming these issues of the `collect` interface:

* The `collect` function allows the caller to specify the desired element type, but does not allow specifying the desired container type.

    * The interface in this package allows the caller to specify the desired output type, not just the element type.

    * This package implements the interface for several `Base` types and invites other packages to implement the interface for their own types.

    * This is basically Julia issue [#36288](https://github.com/JuliaLang/julia/issues/36288) by Takafumi Arakaki.

* The `collect` function may rely on type inference to determine the element type of the output type when the iterator is empty and the element type wasn't specified by the caller.

    * This package lets the caller decide how is the element type of an empty iterator is determined.

        * By default, type inference is not used.

        * By default, an `ArgumentError` is thrown in case a good element type can not be determined.

This package provides a better interface to replace `collect`.

## Usage examples

A `Collect` may be constructed with a no-argument constructor: `Collect()`.

The resulting callable takes two arguments:

* the output type

* an arbitrary iterator

It collects the elements of the iterator into a collection with the provided output type as the type of the collection:

```julia-repl
julia> it = Iterators.map((x -> 0.5 * x), [2, 2, 3]);

julia> Collect()(Vector, it)
3-element Vector{Float64}:
 1.0
 1.0
 1.5

julia> Collect()(Vector{Float32}, it)
3-element Vector{Float32}:
 1.0
 1.0
 1.5

julia> Collect()(Set, it)
Set{Float64} with 2 elements:
  1.0
  1.5

julia> Collect()(Set, [])
ERROR: ArgumentError: couldn't figure out an appropriate element type
[...]

julia> Collect()(Set{Number}, [])
Set{Number}()
```

The behavior for an empty iterator when the element type is not known may be adjusted by passing a keyword argument to the constructor:

```julia-repl
julia> c = Collect(; empty_iterator_handler = Returns(Union{}));

julia> c(Set, [])
Set{Union{}}()

julia> c = Collect(; empty_iterator_handler = EmptyIteratorHandling.may_use_type_inference);

julia> c(Set, Iterators.map((x -> 0.5 * x), 1:0))  # behavior may depend on Julia implementation details
Set{Float64}()
```

It's also possible to collect into a collection with a dimensionality greater than one, assuming the shape can be inferred:

```julia-repl
julia> Collect()(Matrix, Iterators.map(cos, rand(2, 2)))
2×2 Matrix{Float64}:
 0.792873  0.781535
 0.553728  0.941229
```

## Implementations

This package implements the interface for some `Base` types, including:

* `Set`

* `Array`

* `Memory` (when present, on Julia v1.11 and up)

* `Tuple`

Third-party packages are invited to add this package as a (weak or strong) dependency and implement the interface for their types. Some example packages that do this:

* [FixedSizeArrays.jl](https://github.com/JuliaArrays/FixedSizeArrays.jl)

## How to implement for your collection type

To implement the interface for one's own container type, say `Collection`, define a method like this:

```julia
function (c::Collect)(t::Type{<:Collection}, iterator::Any)
    ...
end
```

If `iterator` turns out empty, `eltype(iterator)` is neither the bottom type nor concrete, and `t` doesn't specify an element type, call `(c.empty_iterator_handler)(iterator)` to try to obtain the element type.

## Rough specification

### Identity

If `iterator isa output_type` already, a (shallow) copy of `iterator` must be returned.

### Return type

For each `c`, `output_type` and `iterator` such that `c isa Collect`, if `c(output_type, iterator)` returns a value, the value must be of type `output_type`.

### Element type of the output

The element type must be consistent with `output_type` (as already implied above).

If the output element type does not supertype the element type of `iterator`, the elements of `iterator` are converted into the output element type.

Rule for determining the element type of the output (when applicable, that is, when the output type depends on its element type, and the output type does not subtype `Tuple`):

* If the element type is specified by `output_type`, it's the element type of the output.

* Otherwise, if `iterator` is empty:

    * If `isconcretetype(eltype(iterator)) || (eltype(iterator) <: Union{})`, `eltype(iterator)` is the output element type.

    * Otherwise, the output element type must be determined by `(c.empty_iterator_handler)(iterator)`.

* Otherwise, the output element type is the `typejoin` of the types of the elements of `iterator`.

### Shape of the output

The shape of the output must be consistent with `output_type` (as already implied above).

To the extent that the shape is not specified by `output_type`, it is inferred from `Base.IteratorSize(iterator)`.

### Other rules for implementers to follow

Any added method must take exactly two arguments.

* If you disagree, open a feature request on Github to achieve agreement for adding to the interface.

The first argument of any added method must be constrained to be a type (of type `Type`).

Make sure you own the constraint that is placed on the first argument. This is required even when you know you own the second argument.

* The rationale for this rule is to prevent causing ambiguity for other packages.

* For example, defining a method with a signature like here is *not* allowed, because you don't own `Vector`, even if you do own `A`:

  ```julia
  function (::Collect)(::Type{Vector}, ::A) end
  ```
