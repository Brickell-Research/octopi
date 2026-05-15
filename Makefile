.PHONY: lint lint-fix test build ci

# Check code formatting
lint:
	gleam format --check src/ test/

# Fix code formatting
lint-fix:
	gleam format src/ test/

# Build
build:
	gleam build

# Run tests (Erlang target)
test:
	gleam test

# CI pipeline
ci: lint build test
