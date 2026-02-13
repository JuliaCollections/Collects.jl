using Collects
using Test

function collect_as_through_fixing_single_argument(::Type{T}, collection; empty_iterator_handler::EIH = EmptyIteratorHandling.just_throws) where {T, EIH}
    f = collect_as(T)
    f(collection; empty_iterator_handler)
end

@testset "collect_as: $collect_as" for collect_as ∈ (
    collect_as,
    Collect(; empty_iterator_handler = EmptyIteratorHandling.just_throws),
    Collect(; empty_iterator_handler = EmptyIteratorHandling.may_use_type_inference),
    collect_as_through_fixing_single_argument,
)
    @testset "bottom type" begin
        @test_throws ArgumentError collect_as(Union{}, ())
        @test_throws ArgumentError collect_as(Union{}, [])
    end

    @testset "infinite iterator" begin
        @test_throws ArgumentError collect_as(Vector{Int}, Iterators.cycle(3))
    end

    @testset "`Tuple`" begin
        @test () === @inferred collect_as(Tuple, ())
        @test () === @inferred collect_as(Tuple, Iterators.filter(isodd, Union{}[]))
        @test (3,) === @inferred collect_as(Tuple, 3)
        @test () === collect_as(Tuple, [])
        @test (1, 2, 3) === collect_as(Tuple, [1, 2, 3])
        @test collect_as(Tuple, [1, 2, 3, 4]) === collect_as(Tuple, reshape([1, 2, 3, 4], (2, 2)))
        @test (1, 3) === collect_as(Tuple, Iterators.filter(isodd, 1:4))
        @test (0.5, 1.5) === collect_as(Tuple, Iterators.map((x -> 0.5 * x), Iterators.filter(isodd, 1:4)))
    end

    @testset "`Set`" begin
        @test Set((1, 2)) == (@inferred collect_as(Set{Int}, Set{Int}((1, 2))))::Set{Int}
        @test Set((1, 2)) == (@inferred collect_as(Set{Int}, Set{Float32}((1, 2))))::Set{Int}
        @test Set((1, 2)) == (@inferred collect_as(Set, [1, 1, 2]))::Set{Int}
        @test Set((1, 2)) == (@inferred collect_as(Set{Int}, Float32[1, 1, 2]))::Set{Int}
        @test_throws ArgumentError collect_as(Set, Iterators.map((x -> 3 * x), Number[]))
        @test Set((9,)) == (@inferred collect_as(Set, Iterators.map((x -> 3 * x), 3)))::Set{Int}
        @test Set((3, 6)) == (@inferred collect_as(Set, Iterators.map((x -> 3 * x), (1, 2))))::Set{Int}
        @test Set((3, 6)) == (@inferred collect_as(Set, Iterators.map((x -> 3 * x), (1.0, 2))))::Set{Real}
    end

    @testset "`Array`" begin
        @testset "0D" begin
            @test fill(3) == (@inferred collect_as(Array{Int}, fill(3)))::Array{Int, 0}
            @test fill(3) == (@inferred collect_as(Array{Int, 0}, fill(3)))::Array{Int, 0}
            @test fill(3) == (@inferred collect_as(Array{Int}, fill(3.0)))::Array{Int, 0}
            @test fill(3) == (@inferred collect_as(Array{Int, 0}, fill(3.0)))::Array{Int, 0}
            @test fill(3) == (@inferred collect_as(Array{<:Any, 0}, 3))::Array{Int, 0}
            @test fill(3) == (@inferred collect_as(Array{Float32, 0}, 3))::Array{Float32, 0}
            @test fill(9) == (@inferred collect_as(Array{<:Any, 0}, Iterators.map((x -> 3 * x), 3)))::Array{Int, 0}
        end
        @testset "1D" begin
            @test [3] == (@inferred collect_as(Array{Int}, [3]))::Vector{Int}
            @test [3] == (@inferred collect_as(Vector{Int}, [3]))::Vector{Int}
            @test [3] == (@inferred collect_as(Array{Int}, Float32[3]))::Vector{Int}
            @test [3] == (@inferred collect_as(Vector{Int}, Float32[3]))::Vector{Int}
            @test [9] == (@inferred collect_as(Vector, Iterators.map((x -> 3 * x), 3)))::Vector{Int}
            @test [1, 3] == (@inferred collect_as(Array, Iterators.filter(isodd, 1:4)))::Vector{Int}
            @test [1, 3] == (@inferred collect_as(Array{Int}, Iterators.map(Float32, Iterators.filter(isodd, 1:4))))::Vector{Int}
            @test_throws ArgumentError collect_as(Array, Number[])
            @test [3, 6] == (@inferred collect_as(Vector, Iterators.map((x -> 3 * x), (1.0, 2))))::Vector{Real}
            @test let tup = (false, Int8(1), Int16(2), Int32(3), Int64(4), Int128(5), UInt8(6), UInt16(7), UInt32(8), UInt64(9), UInt128(10))
                it = Iterators.map(Base.Fix1(+, 3), Iterators.filter(iseven, tup))
                ([0, 2, 4, 6, 8, 10] .+ 3) == collect_as(Vector, it)::Vector{Integer}
            end
        end
        @testset "2D" begin
            @test reshape(1:4, (2, 2)) == collect_as(Matrix, reshape(1:4, (2, 2)))::Matrix{Int}
            @test reshape(10:10:40, (2, 2)) == collect_as(Matrix, Iterators.map((x -> 10 * x), reshape(1:4, (2, 2))))::Matrix{Int}
            @test_throws DimensionMismatch collect_as(Matrix, [1])
        end
    end

    (@isdefined Memory) &&
    @testset "`Memory`" begin
        @test [1, 2] == (@inferred collect_as(Memory{Int}, Memory{Int}([1, 2])))::Memory{Int}
        @test [1, 2] == (@inferred collect_as(Memory{Int}, Memory{Float32}([1, 2])))::Memory{Int}
        @test [1, 2, 3] == (@inferred collect_as(Memory, [1, 2, 3]))::Memory{Int}
        @test [2, 4, 6] == (@inferred collect_as(Memory, Iterators.map((x -> 2 * x), (1, 2, 3))))::Memory{Int}
        @test [1, 2, 3] == (@inferred collect_as(Memory{Int}, Float32[1, 2, 3]))::Memory{Int}
        @test [1, 3] == (@inferred collect_as(Memory, Iterators.filter(isodd, 1:4)))::Memory{Int}
        @test let tup = (false, Int8(1), Int16(2), Int32(3), Int64(4), Int128(5), UInt8(6), UInt16(7), UInt32(8), UInt64(9), UInt128(10))
            it = Iterators.map(Base.Fix1(+, 3), Iterators.filter(iseven, tup))
            ([0, 2, 4, 6, 8, 10] .+ 3) == collect_as(Memory, it)::Memory{Integer}
        end
    end
end

@testset "type inference" begin
    iterator = Iterators.map((x -> 0.5 * x), 1:0)
    if Float64 === Collects.EmptyIteratorHandling.@default_eltype iterator
        for collect_as ∈ (
            collect_as,
            collect_as_through_fixing_single_argument,
        )
            @test [] == (@inferred collect_as(Vector, iterator; empty_iterator_handler = EmptyIteratorHandling.may_use_type_inference))::Vector{Float64}
        end
    end
end

module TestAqua
    using Collects
    using Test
    using Aqua: Aqua

    @testset "Aqua.jl" begin
        Aqua.test_all(Collects)
    end
end
