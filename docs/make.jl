using Documenter
using HybridSystemsSimulations
using DataStructures
using DocumenterInterLinks
using Literate

links = InterLinks(
    "Julia" => "https://docs.julialang.org/en/v1/",
    "InfrastructureSystems" => "https://nrel-sienna.github.io/InfrastructureSystems.jl/stable/",
    "PowerSystems" => "https://nrel-sienna.github.io/PowerSystems.jl/stable/",
    "PowerSimulations" => "https://nrel-sienna.github.io/PowerSimulations.jl/stable/",
)

include(joinpath(@__DIR__, "make_tutorials.jl"))
make_tutorials()

pages = OrderedDict(
    "Welcome Page" => "index.md",
    # "Tutorials" => Any[],
    "Reference" => Any[
        "Public API" => "api/public.md",
        "Internals" => "api/internal.md",
    ],
)

makedocs(;
    modules = [HybridSystemsSimulations],
    format = Documenter.HTML(;
        mathengine = Documenter.MathJax(),
        prettyurls = haskey(ENV, "GITHUB_ACTIONS"),
        size_threshold = nothing,
    ),
    sitename = "HybridSystemsSimulations.jl",
    authors = "Jose Daniel Lara, Rodrigo Henriquez-Auba",
    pages = Any[p for p in pages],
    plugins = [links],
)

deploydocs(;
    repo = "github.com/Sienna-Platform/HybridSystemsSimulations.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "main",
    devurl = "dev",
    push_preview = true,
    versions = ["stable" => "v^", "v#.#"],
)
