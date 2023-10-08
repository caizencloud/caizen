.PHONY: help
help:
	@echo "# Options"
	@echo "serve - runs the jekyll serve command"
	@echo "view - opens in browser to view/print to PDF"

.PHONY: serve
serve:
	@docker run --rm -it -v ${PWD}:/docs -p8000:8000 squidfunk/mkdocs-material

.PHONY: view
view:
	@open http://localhost:8000
