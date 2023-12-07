scripts_init:
	julia --startup-file=no --project=scripts/ -e 'using Pkg; Pkg.instantiate(); Pkg.update(); Pkg.precompile();'

project_init:
	julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.update(); Pkg.precompile();'

lint: scripts_init ## Code formating check
	julia --startup-file=no --project=scripts/ scripts/format.jl

format: scripts_init ## Code formating run
	julia --startup-file=no --project=scripts/ scripts/format.jl --overwrite


BRANCH = "dev-4.0.0"
bench: 
	julia --startup-file=no --project=. scripts/bench.jl $(BRANCH)

doc_init:
	julia --project=docs -e 'ENV["PYTHON"]=""; using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate();'

docs: doc_init ## Generate documentation
	julia --project=docs/ docs/make.jl