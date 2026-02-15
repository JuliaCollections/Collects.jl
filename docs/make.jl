using Collects
using Documenter

DocMeta.setdocmeta!(Collects, :DocTestSetup, :(using Collects); recursive=true)

makedocs(;
    modules=[Collects],
    authors="Neven Sajko <s@purelymail.com> and contributors",
    sitename="Collects.jl",
    format=Documenter.HTML(;
        canonical="https://JuliaCollections.github.io/Collects.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaCollections/Collects.jl",
    devbranch="main",
)
