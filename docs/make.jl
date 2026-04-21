using Documenter, HybridSystemsSimulations
import DataStructures: OrderedDict

pages = OrderedDict(
    "Welcome Page" => "index.md",
    "Quick Start Guide" => "quick_start_guide.md",
    "Tutorials" => "tutorials/intro_page.md",
    "Public API Reference" => "api/public.md",
    "Internal API Reference" => "api/internal.md",
)

makedocs(
    modules=[HybridSystemsSimulations],
    format=Documenter.HTML(;
        mathengine=Documenter.MathJax(),
        prettyurls=haskey(ENV, "GITHUB_ACTIONS"),
    ),
    sitename="HybridSystemsSimulations.jl",
    authors="Jose Daniel Lara, Rodrigo Henriquez-Auba",
    pages=Any[p for p in pages],
)

deploydocs(
    repo="github.com/Sienna-Platform/HybridSystemsSimulations.jl.git",
    target="build",
    branch="gh-pages",
    devbranch="main",
    devurl="dev",
    push_preview=true,
    versions=["stable" => "v^", "v#.#"],
)
