.PHONY: help
help:
	@echo "# Options"
	@echo "serve - runs the jekyll serve command"
	@echo "view - opens in browser to view/print to PDF"
	@echo "up - docker compose up"
	@echo "down - docker compose down"
	@echo "tail - tail the container logs"
	@echo "ui - open the memgraph UI"
	@echo "--"
	@echo "local - Run caizen locally"

.PHONY: serve
serve:
	@docker run --rm -it -v ${PWD}:/docs -p8000:8000 squidfunk/mkdocs-material

.PHONY: view
view:
	@open http://localhost:8000

.PHONY: up
up:
	@docker compose up -d -f docker/docker-compose.yml

.PHONY: down
down:
	@docker compose down -f docker/docker-compose.yml

.PHONY: ui
ui:
	@open -a "Google Chrome" "http://localhost:3000"

.PHONY: tail
tail:
	@docker-compose logs -f

.PHONY: local
local:
	@docker compose up -d
	@poetry run uvicorn main:app --app-dir app/ --reload
