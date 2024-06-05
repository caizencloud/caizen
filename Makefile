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
	@echo "delete-all - empty the graph db"
	@echo "load - load resources into the graph db"

.PHONY: serve
serve:
	@docker run --rm -it -v ${PWD}:/docs -p8000:8000 squidfunk/mkdocs-material

.PHONY: view
view:
	@open http://localhost:8000

.PHONY: up
up:
	@docker compose up -d

.PHONY: down
down:
	@docker compose down

.PHONY: ui
ui:
	@open -a "Google Chrome" "http://localhost:3000"

.PHONY: tail
tail:
	@docker-compose logs -f

.PHONY: delete-all
delete-all:
	@echo "# Deleting everthing in the graph"
	@curl -s -XDELETE localhost:8000/resources -o /dev/null
	@echo "# Done."

.PHONY: load
load:
	@echo "# Deleting everthing in the graph"
	@docker exec -i caizen-db-1 mgconsole < supporting/cypher/delete-all.cypherl
	@echo "# Done."
	@echo "# Loading Resources into the graph"
	@docker exec -i caizen-db-1 mgconsole < supporting/cypher/load-resources.cypherl 
	@echo "# Done."

.PHONY: local
local:
	@docker compose up -d
	@poetry run uvicorn main:api --app-dir api/ --reload

.PHONY: lint
lint:
	@poetry run flake8 api tests

.PHONY: get-all
get-all:
	@curl -s -H "Content-type: application/json" localhost:8000/resources | jq

.PHONY: query-all
query-all:
	@curl -s -XPOST -d'{"query": "MATCH (n)-[r]->(d) return n,r,d"}' -H "Content-type: application/json" localhost:8000/q | jq
