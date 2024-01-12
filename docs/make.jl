using Documenter, GraphPPL

makedocs(
    modules  = [ GraphPPL ],
    clean    = true,
    sitename = "GraphPPL.jl",
    pages    = [
        "Home"                 => "index.md",
        "User guide"           => "user-guide.md",
        "Utils"                => "utils.md"
    ],
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    )
)

if get(ENV, "CI", nothing) == "true"
    deploydocs(
        repo = "github.com/ReactiveBayes/GraphPPL.jl.git",
        devbranch = "main", 
        forcepush = true
    )
end
