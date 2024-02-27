using Documenter, GraphPPL

DocMeta.setdocmeta!(GraphPPL, :DocTestSetup, :(using GraphPPL); recursive = true)

makedocs(
    modules  = [ GraphPPL ],
    clean    = true,
    sitename = "GraphPPL.jl",
    pages    = [
        "Home"                  => "index.md",
        "Getting Started"       => "getting_started.md",
        "Nested Models"         => "nested_models.md",
        "Constraint Specification" => "constraint_specification.md",
        "Developers Guide"      => "developers_guide.md"
    ],
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    warnonly = true   
)

if get(ENV, "CI", nothing) == "true"
    deploydocs(
        repo = "github.com/biaslab/GraphPPL.jl.git"
    )
end
