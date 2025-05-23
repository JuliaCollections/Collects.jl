using CollectAs
using Test
using Aqua

@testset "CollectAs.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(CollectAs)
    end
    # Write your tests here.
end
