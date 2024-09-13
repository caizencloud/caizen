.DEFAULT_GOAL := help

help:
	@echo "Usage:"
	@echo "  make export-requirements  - Export dependencies to requirements.txt"
	@echo "  make help                 - Show this help message"

export-requirements:
	@echo "Export requirements.txt using Poetry"
	@poetry export --without-hashes --format=requirements.txt > requirements.txt
