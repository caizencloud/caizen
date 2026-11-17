.DEFAULT_GOAL := help
.PHONY: help docs-serve docs-build

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

docs-serve: ## Serve the docs site at http://localhost:1313 with live reload
	cd docs && hugo server --buildDrafts --disableFastRender --noHTTPCache --renderToMemory

docs-build: ## Build the docs site into docs/public
	cd docs && hugo --gc --minify
