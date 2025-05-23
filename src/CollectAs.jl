module CollectAs
    export collect_as

    """
        collect_as(output_type::Type, collection)

    Collect the elements of `collection` into a value of type `output_type` and return the resulting collection.

    For context, `collect_as` is a generalization of the two-argument `collect` from `Base`.

    Regarding identity:

    * If `collection isa output_type` already, a copy of `collection` is returned.

    Regarding the element type of the output:

    * It must be consistent with `output_type`.

    * When necessary, the elements of `collection` are converted into the output element type.

    * Rule for determining the element type of the output (when applicable, that is, when the output type depends on its element type, and the output type does not subtype `Tuple`):

        * If the element type is specified by `output_type`, it's the element type of the output.

        * Otherwise, if `collection` is empty: If `isconcretetype(eltype(iterator))`, `eltype(iterator)` is the output element type, otherwise, `Union{}` is the output element type.

        * Otherwise, the output element type is the `typejoin` of the types of the elements of `collection`.

    Regarding the shape of the output:

    * It must be consistent with `output_type`.

    * To the extent that the shape is not specified by `output_type`, it is inferred from `Base.IteratorSize(collection)`.

    Other rules for implementors to follow:

    * Any added method must take exactly two arguments.
    
    * The first argument of any added method must be constrained to be a type (of type `Type`).

    * Make sure you own the constraint that is placed on the first argument. This is required even when you know you own the second argument.

        * The rationale for this rule is to prevent causing ambiguity for other packages.

        * For example, defining a method with a signature like here is *not* allowed, because you don't own `Vector`, even if you do own `A`:

          ```julia
          function CollectAs.collect_as(::Type{Vector}, ::A) end
          ```
    """
    function collect_as end

    Base.@constprop :aggressive function push!!(coll::Set, elem)
        if elem isa eltype(coll)
            push!(coll, elem)
        else
            let E = typejoin(typeof(elem), eltype(coll))
                ret = Set{E}((elem,))
                ret = sizehint!(ret, length(coll); shrink = false)
                union!(ret, coll)
            end
        end
    end

    Base.@constprop :aggressive function push!!(coll::Vector, elem)
        if elem isa eltype(coll)
            push!(coll, elem)
        else
            let E = typejoin(typeof(elem), eltype(coll))
                ret = Vector{E}(undef, length(coll) + 1)
                ret = copyto!(ret, coll)
                ret[end] = elem
                ret
            end
        end
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
        if (!isone(output)) && (output != input)
            throw(DimensionMismatch("dimension count mismatch: can't collect $input dimensions into $output dimensions"))
        end
        output
    end

    Base.@constprop :aggressive function check_ndims_consistency(ndims::Int, collection)
        check_ndims_consistency_impl(ndims, infer_ndims(collection))
    end

    Base.@constprop :aggressive function normalize_type(::Type{T}) where {T}
        function normalize_type_val(::Val{S}) where {S}
            S  # https://github.com/JuliaLang/julia/discussions/58515
        end
        normalize_type_val(Val{T}())
    end

    # Prevent accidental type piracy in dependent packages.
    function collect_as(::Type{Union{}}, ::Any)
        throw(ArgumentError("`Union{}` is not a type of a collection"))
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

    const ConstructorUnionFineInvariant = Union{
        Type{Set},
        (Type{Set{T}} where {T}),
        Type{Array},
        (Type{Array{T}} where {T}),
        (Type{Array{T, N} where {T}} where {N}),
        (Type{Array{T, N}} where {T, N}),
        if optional_memory === ()
            Union{}
        else
            let M = only(optional_memory)
                Union{
                    Type{M},
                    (Type{M{T}} where {T}),
                }
            end
        end,
    }

    const ConstructorUnionFine = Union{Type{Tuple}, ConstructorUnionFineInvariant}

    Base.@constprop :aggressive function collect_as_set_with_unknown_eltype(collection)
        iter = Iterators.peel(collection)
        if iter === nothing
            Set{Union{}}()
        else
            let (fir, rest) = iter
                coll = Set((fir,))
                for e ∈ rest
                    coll = push!!(coll, e)
                end
                coll
            end
        end
    end

    Base.@constprop :aggressive function collect_as_set_with_known_eltype(::Type{T}, collection) where {T}
        ret = Set{T}()
        if Base.IteratorSize(collection) isa Union{Base.HasLength, Base.HasShape}
            ret = sizehint!(ret, length(collection); shrink = false)
        end
        foreach(Base.Fix1(push!, ret), collection)
        ret
    end

    Base.@constprop :aggressive function collect_as_set(::Type{Set}, collection)
        T = eltype(collection)
        if isconcretetype(T)
            collect_as_set_with_known_eltype(T, collection)
        else
            collect_as_set_with_unknown_eltype(collection)
        end
    end

    Base.@constprop :aggressive function collect_as_set(::Type{Set{T}}, collection) where {T}
        collect_as_set_with_known_eltype(T, collection)
    end

    Base.@constprop :aggressive function collect_as_array_with_unknown_eltype(ndims::Int, collection)
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
                    Array{Union{}, ndims}(undef, zeros_tuple(ndims))
                else
                    let (fir, rest) = iter
                        vec = [fir]
                        for e ∈ rest
                            vec = push!!(vec, e)
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

    Base.@constprop :aggressive function collect_as_array_with_known_eltype(::Type{T}, ndims::Int, collection) where {T}
        ndims = check_ndims_consistency(ndims, collection)
        if iszero(ndims)
            let e = only(collection)
                ret = Array{T, 0}(undef)
                ret[] = e
                ret
            end
        else
            let
                size_hint = if Base.IteratorSize(collection) isa Union{Base.HasLength, Base.HasShape}
                    length(collection)
                else
                    0
                end
                vec = empty!(Vector{T}(undef, size_hint))
                foreach(Base.Fix1(push!, vec), collection)
                if isone(ndims)
                    vec
                else
                    reshape(vec, size(collection))
                end
            end
        end
    end

    Base.@constprop :aggressive function collect_as_array_with_optional_eltype(::Type{T}, N::Int, collection) where {T}
        if isconcretetype(T)
            collect_as_array_with_known_eltype(T, N, collection)
        else
            collect_as_array_with_unknown_eltype(N, collection)
        end
    end

    Base.@constprop :aggressive function collect_as_array(::Type{Array}, collection)
        T = eltype(collection)
        N = infer_ndims(collection)
        collect_as_array_with_optional_eltype(T, N, collection)
    end

    Base.@constprop :aggressive function collect_as_array(::Type{Array{T}}, collection) where {T}
        N = infer_ndims(collection)
        collect_as_array_with_known_eltype(T, N, collection)
    end

    Base.@constprop :aggressive function collect_as_array(::Type{Array{T, N} where {T}}, collection) where {N}
        T = eltype(collection)
        collect_as_array_with_optional_eltype(T, N, collection)
    end

    Base.@constprop :aggressive function collect_as_array(::Type{Array{T, N}}, collection) where {T, N}
        collect_as_array_with_known_eltype(T, N, collection)
    end

    Base.@constprop :aggressive function collect_as_common_invariant(::Type{C}, collection) where {C <: Set}
        collect_as_set(C, collection)
    end

    Base.@constprop :aggressive function collect_as_common_invariant(::Type{C}, collection) where {C <: Array}
        collect_as_array(C, collection)
    end

    if optional_memory !== ()
        Base.@constprop :aggressive function collect_as_memory(::Type{only(optional_memory)}, collection)
            vec = collect_as(Vector, collection)
            convert(only(optional_memory){eltype(vec)}, vec)
        end
        Base.@constprop :aggressive function collect_as_memory(::Type{only(optional_memory){T}}, collection) where {T}
            convert(only(optional_memory){T}, collect_as(Vector{T}, collection))
        end
        Base.@constprop :aggressive function collect_as_common_invariant(::Type{C}, collection) where {C <: only(optional_memory)}
            collect_as_memory(C, collection)
        end
    end

    Base.@constprop :aggressive function collect_as_tuple(::Type{Tuple}, iterator)
        (collect_as(Vector, iterator)...,)
    end

    Base.@constprop :aggressive function collect_as_tuple(::Type{Tuple}, iterator::Union{optional_memory..., Array, Pair, NamedTuple, Number})
        (iterator...,)
    end

    function collect_as_tuple(::Type{Tuple}, iterator::Tuple)
        iterator
    end

    Base.@constprop :aggressive function collect_as_common(type::ConstructorUnionFineInvariant, collection)
        collect_as_common_invariant(type, collection)
    end

    Base.@constprop :aggressive function collect_as_common(type::Type{<:Tuple}, collection)
        collect_as_tuple(type, collection)
    end

    Base.@constprop :aggressive function collect_as(type::ConstructorUnionRough, collection)
        if Base.IteratorSize(collection) === Base.IsInfinite()
            throw(DimensionMismatch("can't collect infinitely many elements into a finite collection"))
        end
        collect_as_common(normalize_type(type), collection)
    end
end
