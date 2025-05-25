using CollectAs
using Test
using Aqua: Aqua

@testset "CollectAs.jl" begin
    @testset "bottom type" begin
        @test_throws ArgumentError collect_as(Union{}, ())
        @test_throws ArgumentError collect_as(Union{}, [])
    end

    @testset "infinite iterator" begin
        @test_throws ArgumentError collect_as(Vector{Int}, Iterators.cycle(3))
    end

    @testset "`Tuple`" begin
        @test () === @inferred collect_as(Tuple, ())
        @test (3,) === @inferred collect_as(Tuple, 3)
        @test () === collect_as(Tuple, [])
        @test (1, 2, 3) === collect_as(Tuple, [1, 2, 3])
        @test collect_as(Tuple, [1, 2, 3, 4]) === collect_as(Tuple, reshape([1, 2, 3, 4], (2, 2)))
        @test (1, 3) === collect_as(Tuple, Iterators.filter(isodd, 1:4))
    end

    @testset "`Set`" begin
        @test Set((1, 2)) == (@inferred collect_as(Set, [1, 1, 2]))::Set{Int}
        @test Set((1, 2)) == (@inferred collect_as(Set{Int}, Float32[1, 1, 2]))::Set{Int}
        @test Set{Int}() == (@inferred collect_as(Set, Iterators.map((x -> 3 * x), ())))::Set{Union{}}
        @test Set((9,)) == (@inferred collect_as(Set, Iterators.map((x -> 3 * x), 3)))::Set{Int}
        @test Set((3, 6)) == (@inferred collect_as(Set, Iterators.map((x -> 3 * x), (1, 2))))::Set{Int}
        @test Set((3, 6)) == (@inferred collect_as(Set, Iterators.map((x -> 3 * x), (1.0, 2))))::Set{Real}
    end

    @testset "`Array`" begin
        @testset "0D" begin
            @test fill(3) == (@inferred collect_as(Array{<:Any, 0}, 3))::Array{Int, 0}
            @test fill(9) == (@inferred collect_as(Array{<:Any, 0}, Iterators.map((x -> 3 * x), 3)))::Array{Int, 0}
        end
        @testset "1D" begin
            @test [9] == (@inferred collect_as(Vector, Iterators.map((x -> 3 * x), 3)))::Vector{Int}
            @test [1, 3] == (@inferred collect_as(Array, Iterators.filter(isodd, 1:4)))::Vector{Int}
            @test [1, 3] == (@inferred collect_as(Array{Int}, Iterators.map(Float32, Iterators.filter(isodd, 1:4))))::Vector{Int}
            @test [] == collect_as(Array, Number[])::Vector{Union{}}
            @test [3, 6] == (@inferred collect_as(Vector, Iterators.map((x -> 3 * x), (1.0, 2))))::Vector{Real}
        end
        @testset "2D" begin
            @test reshape(1:4, (2, 2)) == collect_as(Matrix, reshape(1:4, (2, 2)))::Matrix{Int}
            @test reshape(10:10:40, (2, 2)) == collect_as(Matrix, Iterators.map((x -> 10 * x), reshape(1:4, (2, 2))))::Matrix{Int}
            @test_throws DimensionMismatch collect_as(Matrix, [1])
        end
    end

    (@isdefined Memory) &&
    @testset "`Memory`" begin
        @test [1, 2, 3] == (@inferred collect_as(Memory, [1, 2, 3]))::Memory{Int}
        @test [2, 4, 6] == (@inferred collect_as(Memory, Iterators.map((x -> 2 * x), (1, 2, 3))))::Memory{Int}
        @test [1, 2, 3] == (@inferred collect_as(Memory{Int}, Float32[1, 2, 3]))::Memory{Int}
        @test [1, 3] == (@inferred collect_as(Memory, Iterators.filter(isodd, 1:4)))::Memory{Int}
    end

    @testset "Aqua.jl" begin
        Aqua.test_all(CollectAs)
    end
end
