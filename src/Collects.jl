module Collects
    export Collect, EmptyIteratorHandling, collect_as

    module TypeUtil
        export is_precise, normalize
        Base.@constprop :aggressive function is_precise(::Type{T}) where {T}
            isconcretetype(T) || (T <: Union{})
        end
        Base.@constprop :aggressive function normalize(::Type{T}) where {T}
            function f(::Val{S}) where {S}
                S  # https://github.com/JuliaLang/julia/discussions/58515
            end
            f(Val{T}())
        end
    end

    """
        EmptyIteratorHandling::Module

    Exports [`just_throws`](@ref) and [`may_use_type_inference`](@ref), which are
    meant as arguments for [`Collect`](@ref).
    """
    module EmptyIteratorHandling
        export just_throws, may_use_type_inference
        using ..TypeUtil
        @noinline function throw_err_eltype(collection_type::DataType)
             err = ArgumentError(lazy"couldn't figure out an appropriate element type for collection of type $collection_type")
             throw(err)
        end
        """
            just_throws(iterator)::Union{}

        Throw an `ArgumentError`.
        """
        function just_throws(iterator)
            t = typeof(iterator)
            throw_err_eltype(t)
        end
        if isdefined(Base, Symbol("@default_eltype"))
            macro default_eltype(itr)
                i = esc(itr)
                :(Base.@default_eltype $i)
            end
        else
            # correct fallback
            macro default_eltype(::Any)
                Any
            end
        end
        """
            may_use_type_inference(iterator)::Type

        Run type inference to try to determine the element type. If the obtained type is
        either concrete or bottom, return it, or an equal type.

        Throw otherwise.

        Beware:

        * Type inference is accessed using `Base.@default_eltype`, which is not a public
          interface of `Base`, thus it may change behavior on upgrading Julia,
          potentially breaking this function.

        * The exact result of a type inference query is, of course, just an
          implementation detail of Julia's compiler.

        * Type inference results may differ from run to run. Type inference is stateful,
          some things that may affect the results of a type inference query are:
          defining a method, loading a package or running a type inference query.

        * Relying on type inference may prevent compiler optimizations, such as constant
          folding.

        * Publicly exposing the results of type inference makes for a bad interface.
          Only use it as an optimization.
        """
        Base.@constprop :aggressive function may_use_type_inference(iterator)
            @inline
            s = @inline TypeUtil.normalize(@default_eltype iterator)
            if TypeUtil.is_precise(s)
                return s
            end
            just_throws(iterator)
        end
    end

    using .EmptyIteratorHandling

    """
        Collect(; empty_iterator_handler)

    Return a callable value. The returned callable behaves similarly to the `collect`
    function from `Base`. In fact it generalizes `collect`, and is meant to be *what
    `collect` should have been*. See the package Readme for more details.

    The keyword argument `empty_iterator_handler`:

    * configures how the returned callable will behave when called with an empty
      iterator

    * is accessible as a property of any `Collect` value
    """
    struct Collect{EmptyIteratorHandler} <: Function
        empty_iterator_handler::EmptyIteratorHandler
        Base.@constprop :aggressive function Collect(; empty_iterator_handler::EIH) where {EIH}
            new{EIH}(empty_iterator_handler)
        end
    end

    Base.@constprop :aggressive function length_int(collection)
        Int(length(collection))::Int
    end

    Base.@constprop :aggressive function typejoin_typeof_eltype(; coll, elem)
        elt = eltype(coll)
        typ = typeof(elem)
        typejoin(elt, typ)
    end

    Base.@constprop :aggressive function push(coll::Set, elem)
        E = typejoin_typeof_eltype(; coll, elem)
        ret = Set{E}(coll)
        push!(ret, elem)
    end

    Base.@constprop :aggressive function push_vector_prefix(coll, prefix_length::Int, elem)
        E = typejoin_typeof_eltype(; coll, elem)
        prefix = @view coll[begin:(begin + (prefix_length - 1))]
        ret = Vector{E}(undef, prefix_length + 1)
        ret = copyto!(ret, prefix)
        ret[end] = elem
        ret
    end

    Base.@constprop :aggressive function push(coll::Vector, elem)
        len = length_int(coll)
        push_vector_prefix(coll, len, elem)
    end

    Base.@constprop :aggressive function push!!(coll::Union{Set, Vector}, elem)
        elt = eltype(coll)
        if elem isa elt
            push!(coll, elem)
        else
            push(coll, elem)
        end
    end

    Base.@constprop :aggressive function append!!(x::Union{Set, Vector}, y)
        for e ∈ y
            x = push!!(x, e)
        end
        x
    end

    Base.@constprop :aggressive function zeros_tuple(n::Int)
        ntuple(Returns(0), Val(n))
    end

    function infer_ndims_impl(::Base.HasShape{N}) where {N}
        N::Int
    end

    function infer_ndims_impl(::Base.IteratorSize)
        1
    end

    Base.@constprop :aggressive function infer_ndims(iterator)
        infer_ndims_impl(Base.IteratorSize(iterator))
    end

    Base.@constprop :aggressive function check_ndims_consistency_impl(output::Int, input::Int)
        @noinline function mismatch_throw(output::Int, input::Int)
            throw(DimensionMismatch(lazy"dimension count mismatch: can't collect $input dimensions into $output dimensions"))
        end
        if (!isone(output)) && (output != input)
            @noinline mismatch_throw(output, input)
        end
        output
    end

    Base.@constprop :aggressive function check_ndims_consistency(ndims::Int, collection)
        check_ndims_consistency_impl(ndims, infer_ndims(collection))
    end

    const IteratorHasLength = Union{Base.HasLength, Base.HasShape}

    Base.@constprop :aggressive function iterator_has_length(iterator)
        Base.IteratorSize(iterator) isa IteratorHasLength
    end

    @noinline function throw_err_empty_union()
        throw(ArgumentError("`Union{}` is not a type of a collection"))
    end

    # Prevent accidental type piracy in dependent packages.
    function (::Collect)(::Type{Union{}}, ::Any)
        throw_err_empty_union()
    end

    const optional_memory = (@isdefined Memory) ? (Memory,) : ()

    const ConstructorUnionRough = Union{
        (Type{T} where {T <: Tuple}),
        (Type{T} where {T <: Set}),
        (Type{T} where {T <: Array}),
        if optional_memory === ()
            Union{}
        else
            (Type{T} where {T <: only(optional_memory)})
        end,
    }

    const ConstructorUnionFineInvariantWithEltype = Union{
        (Type{Set{T}} where {T}),
        (Type{Array{T}} where {T}),
        (Type{Array{T, N}} where {T, N}),
        if optional_memory === ()
            Union{}
        else
            Type{Memory{T}} where {T}
        end,
    }

    const ConstructorUnionFineInvariantWithoutEltype = Union{
        Type{Set},
        Type{Array},
        (Type{Array{T, N} where {T}} where {N}),
        if optional_memory === ()
            Union{}
        else
            Type{Memory}
        end,
    }

    const ConstructorUnionFineInvariant = Union{
        ConstructorUnionFineInvariantWithEltype,
        ConstructorUnionFineInvariantWithoutEltype,
    }

    const ConstructorUnionFineInvariantWithNdims = Union{
        (Type{Array{T, N} where {T}} where {N}),
        (Type{Array{T, N}} where {T, N}),
        if optional_memory === ()
            Union{}
        else
            Union{
                Type{Memory},
                (Type{Memory{T}} where {T}),
            }
        end,
    }

    const ConstructorUnionFineInvariantWithoutNdims = Union{
        Type{Array},
        (Type{Array{T}} where {T}),
    }

    Base.@constprop :aggressive function type_predicate_exhaustive(type::Type; true_supertype::Type{<:Type}, false_supertype::Type{<:Type})
        let r
            if type isa true_supertype
                r = true
            elseif type isa false_supertype
                r = false
            end
            r
        end
    end

    Base.@constprop :aggressive function type_has_eltype(type::Type)
        true_supertype = ConstructorUnionFineInvariantWithEltype
        false_supertype = ConstructorUnionFineInvariantWithoutEltype
        type_predicate_exhaustive(type; true_supertype, false_supertype)
    end

    Base.@constprop :aggressive function type_has_ndims(type::Type)
        true_supertype = ConstructorUnionFineInvariantWithNdims
        false_supertype = ConstructorUnionFineInvariantWithoutNdims
        type_predicate_exhaustive(type; true_supertype, false_supertype)
    end

    Base.@constprop :aggressive function collect_as_set_with_unknown_eltype(e::E, collection) where {E}
        iter = Iterators.peel(collection)
        if iter === nothing
            Set{e(collection)}()
        else
            let (fir, rest) = iter
                coll = Set((fir,))
                append!!(coll, rest)
            end
        end
    end

    Base.@constprop :aggressive function collect_as_set_with_known_eltype(::Type{T}, collection::Set{T}) where {T}
        copy(collection)
    end
    Base.@constprop :aggressive function collect_as_set_with_known_eltype(::Type{T}, collection) where {T}
        ret = Set{T}()
        foreach(Base.Fix1(push!, ret), collection)
        ret
    end

    Base.@constprop :aggressive function collect_as_vector_with_initial(initial, initial_length::Int, next, rest)
        vec = push_vector_prefix(initial, initial_length, next)
        append!!(vec, rest)
    end

    Base.@constprop :aggressive function collect_as_vector_with_unknown_eltype_and_known_length(type::Type, first, rest, len::Int)
        T = typeof(first)
        vec = type{T}(undef, len)
        i = 1
        vec[i] = first
        while true
            iter = Iterators.peel(rest)
            if iter === nothing
                break
            end
            (next, rest) = iter
            if next isa T
                i += 1
                vec[i] = next
            else
                return collect_as_vector_with_initial(vec, i, next, rest)
            end
        end
        vec
    end

    Base.@constprop :aggressive function collect_as_vector_with_unknown_eltype_and_unknown_length(first, rest)
        append!!([first], rest)
    end

    Base.@constprop :aggressive function collect_as_array_with_unknown_eltype(e::E, ndims::Int, collection) where {E}
        ndims = check_ndims_consistency(ndims, collection)
        if iszero(ndims)
            let e = only(collection)
                ret = Array{typeof(e), 0}(undef)
                ret[] = e
                ret
            end
        else
            let iter = Iterators.peel(collection)
                if iter === nothing
                    Array{e(collection), ndims}(undef, zeros_tuple(ndims))
                else
                    let (fir, rest) = iter
                        vec = if iterator_has_length(collection)
                            collect_as_vector_with_unknown_eltype_and_known_length(Vector, fir, rest, length_int(collection))
                        else
                            collect_as_vector_with_unknown_eltype_and_unknown_length(fir, rest)
                        end
                        if isone(ndims)
                            vec
                        else
                            reshape(vec, size(collection))
                        end
                    end
                end
            end
        end
    end

    Base.@constprop :aggressive function collect_as_vectorlike_with_known_eltype_and_length(::Type{V}, collection) where {V <: AbstractVector}
        vec = V(undef, length_int(collection))
        copyto!(vec, collection)
    end

    Base.@constprop :aggressive function collect_as_vector_with_known_eltype(::Type{V}, collection) where {V <: AbstractVector}
        vec = V(undef, 0)
        foreach(Base.Fix1(push!, vec), collection)
        vec
    end

    Base.@constprop :aggressive function collect_as_array_with_known_eltype(::Type{T}, ndims::Int, collection) where {T}
        ndims = check_ndims_consistency(ndims, collection)
        if collection isa Array{T, ndims}
            copy(collection)
        elseif iszero(ndims)
            let e = only(collection)
                ret = Array{T, 0}(undef)
                ret[] = e
                ret
            end
        else
            let V = Vector{T}
                vec = if iterator_has_length(collection)
                    collect_as_vectorlike_with_known_eltype_and_length(V, collection)
                else
                    collect_as_vector_with_known_eltype(V, collection)
                end
                if isone(ndims)
                    vec
                else
                    reshape(vec, size(collection))
                end
            end
        end
    end

    if optional_memory !== ()
        Base.@constprop :aggressive function collect_as_memory_with_known_eltype_and_known_length(::Type{T}, collection::Memory{T}) where {T}
            copy(collection)
        end
        Base.@constprop :aggressive function collect_as_memory_with_known_eltype_and_known_length(::Type{T}, collection) where {T}
            collect_as_vectorlike_with_known_eltype_and_length(Memory{T}, collection)
        end
        Base.@constprop :aggressive function collect_as_memory_with_known_eltype_and_unknown_length(::Type{T}, collection) where {T}
            vec = collect_as_array_with_known_eltype(T, 1, collection)
            collect_as_memory_with_known_eltype_and_known_length(T, vec)
        end
        Base.@constprop :aggressive function collect_as_memory_with_known_eltype(::Type{T}, collection) where {T}
            if iterator_has_length(collection)
                collect_as_memory_with_known_eltype_and_known_length(T, collection)
            else
                collect_as_memory_with_known_eltype_and_unknown_length(T, collection)
            end
        end
        Base.@constprop :aggressive function collect_as_memory_with_unknown_eltype_and_known_length(e::E, collection) where {E}
            iter = Iterators.peel(collection)
            if iter === nothing
                return Memory{e(collection)}(undef, 0)
            end
            (fir, rest) = iter
            vec = collect_as_vector_with_unknown_eltype_and_known_length(Memory, fir, rest, length_int(collection))
            if vec isa Memory
                vec
            else
                collect_as_memory_with_known_eltype(eltype(vec), vec)
            end
        end
        Base.@constprop :aggressive function collect_as_memory_with_unknown_eltype_and_unknown_length(e::E, collection) where {E}
            vec = collect_as_array_with_unknown_eltype(e, 1, collection)
            collect_as_memory_with_known_eltype(eltype(vec), vec)
        end
        Base.@constprop :aggressive function collect_as_memory_with_unknown_eltype(e::E, collection) where {E}
            if iterator_has_length(collection)
                collect_as_memory_with_unknown_eltype_and_known_length(e, collection)
            else
                collect_as_memory_with_unknown_eltype_and_unknown_length(e, collection)
            end
        end
    end

    Base.@constprop :aggressive function collect_as_common_invariant(e::E, type::Type, collection) where {E}
        has_eltype = type_has_eltype(type)
        elt = if has_eltype
            eltype(type)
        else
            eltype(collection)
        end
        subtypes_set = type <: Set
        subtypes_memory = (optional_memory !== ()) && (type <: Memory)
        subtypes_array = type <: Array
        let r, n
            if subtypes_array
                n = if type_has_ndims(type)
                    ndims(type)::Int
                else
                    infer_ndims(collection)::Int
                end
            end
            if has_eltype || TypeUtil.is_precise(elt)
                if subtypes_set
                    r = collect_as_set_with_known_eltype(elt, collection)
                elseif subtypes_memory
                    r = collect_as_memory_with_known_eltype(elt, collection)
                elseif subtypes_array
                    r = collect_as_array_with_known_eltype(elt, n, collection)
                end
            else
                if subtypes_set
                    r = collect_as_set_with_unknown_eltype(e, collection)
                elseif subtypes_memory
                    r = collect_as_memory_with_unknown_eltype(e, collection)
                elseif subtypes_array
                    r = collect_as_array_with_unknown_eltype(e, n, collection)
                end
            end
            r
        end
    end

    Base.@constprop :aggressive function collect_as_tuple(::Type{Tuple}, iterator)
        t = TypeUtil.normalize(eltype(iterator))
        if isconcretetype(t)
            (collect_as_array_with_known_eltype(t, 1, iterator)...,)
        elseif t <: Union{}
            (iterator...,)::Tuple{}
        else
            (collect_as_array_with_unknown_eltype(Returns(Union{}), 1, iterator)...,)
        end
    end

    Base.@constprop :aggressive function collect_as_tuple(::Type{Tuple}, iterator::Union{optional_memory..., Array, Pair, NamedTuple, Number})
        (iterator...,)
    end

    function collect_as_tuple(::Type{Tuple}, iterator::Tuple)
        iterator
    end

    Base.@constprop :aggressive function collect_as_common(e::E, type::ConstructorUnionFineInvariant, collection) where {E}
        collect_as_common_invariant(e, type, collection)
    end

    Base.@constprop :aggressive function collect_as_common(::Any, type::Type{<:Tuple}, collection)
        collect_as_tuple(type, collection)
    end

    Base.@constprop :aggressive function (collect::Collect)(type::ConstructorUnionRough, collection)
        @noinline function infinite_throw()
            throw(ArgumentError("can't collect infinitely many elements into a finite collection"))
        end
        if Base.IteratorSize(collection) === Base.IsInfinite()
            @noinline infinite_throw()
        end
        collect_as_common(collect.empty_iterator_handler, TypeUtil.normalize(type), collection)
    end

    """
        collect_as(output_type::Type, collection; empty_iterator_handler)

    Collect `collection` into a collection of type `output_type`. The optional keyword
    argument `empty_iterator_handler` may be used to control the behavior for when
    `collection` is empty.

    Do not add any method. This function just forwards to [`Collect`](@ref).
    """
    Base.@constprop :aggressive function collect_as(::Type{T}, collection; empty_iterator_handler::EIH = just_throws) where {T, EIH}
        c = Collect(; empty_iterator_handler)
        c(T, collection)
    end

    """
        collect_as(output_type::Type)

    Return a callable which:

    * Takes a collection, `collection`, as the only positional argument.

    * Takes the same keyword arguments as the `collect_as` method with two positional arguments. Say, `kwargs`.

    * Calls `collect_as(output_type, collection; kwargs...)` and returns the result.

    Mostly equivalent to `Base.Fix1(collect_as, output_type)`.
    """
    Base.@constprop :aggressive function collect_as(::Type{T}) where {T}
        Base.@constprop :aggressive function collect_as_with_fixed_requested_output_type(collection; empty_iterator_handler::EIH = just_throws) where {EIH}
            collect_as(T, collection; empty_iterator_handler)
        end
    end
end
