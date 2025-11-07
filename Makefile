scripts_init:
	julia --startup-file=no --project=scripts/ -e 'using Pkg; Pkg.instantiate(); Pkg.update(); Pkg.precompile();'

project_init:
	julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.update(); Pkg.precompile();'

lint: scripts_init ## Code formating check
	julia --startup-file=no --project=scripts/ scripts/format.jl

format: scripts_init ## Code formating run
	julia --startup-file=no --project=scripts/ scripts/format.jl --overwrite

bench: ## Run benchmark, use `make bench branch=...` to test against a specific branch
	julia --startup-file=no --project=scripts/ scripts/bench.jl $(branch)

doc_init:
	julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate();'

docs: doc_init ## Generate documentation
	julia --project=docs/ docs/make.jl

.PHONY: test
test: ## Run tests (make test test_args="folder1:test1 folder2:test2" to run reduced testsets. RUN_AQUA=false make test ... to skip slow Aqua checks enabled by default)
	julia -e 'import Pkg; Pkg.activate("."); Pkg.test(test_args = split("$(test_args)") .|> string)'	