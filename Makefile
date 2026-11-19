.DEFAULT_GOAL := help
.PHONY: help docs-serve docs-build testdata-capture

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

docs-serve: ## Serve the docs site at http://localhost:1313 with live reload
	cd docs && hugo server --buildDrafts --disableFastRender --noHTTPCache --renderToMemory

docs-build: ## Build the docs site into docs/public
	cd docs && hugo --gc --minify

testdata-capture: ## Copy the latest collector runs from BUCKET into app/e2e/testdata/raw (EXCLUDE_ANCESTORS=folders/<id>,...)
	BUCKET=$(BUCKET) EXCLUDE_ANCESTORS=$(EXCLUDE_ANCESTORS) ./app/e2e/capture.sh
