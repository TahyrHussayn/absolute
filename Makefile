# ==============================================================================
# Absolute — Repository Makefile (Polyglot DevOps Task Runner)
# ==============================================================================

.PHONY: help setup dev test precommit bootstrap docker-prod clean

help:
	@echo "Available commands:"
	@echo "  make setup       - Install dependencies, setup database, build assets"
	@echo "  make dev         - Start local Phoenix server and dev environment"
	@echo "  make test        - Run ExUnit test suite"
	@echo "  make precommit   - Run compile checks, format checks, and test suite"
	@echo "  make bootstrap   - Run Day 0 AWS Infrastructure & OIDC Bootstrap"
	@echo "  make docker-prod - Run complete production stack locally in Docker"

setup:
	@mix setup

dev:
	@mix phx.server

test:
	@mix test

precommit:
	@mix precommit

bootstrap:
	@mix bootstrap

docker-prod:
	@docker compose -f compose.prod.yaml up -d --build
	@docker compose -f compose.prod.yaml exec app /app/bin/migrate

destroy:
	@mix destroy
