SHELL=/bin/bash

-include .env

STATIC_ANALYSIS_CHECKER := $(shell which shellcheck 2> /dev/null)
LINTER_CHECKER := $(shell which ec 2> /dev/null)
GIT_DIR = $(shell git rev-parse --git-dir 2> /dev/null)

OS:=
ifeq ($(OS),Windows_NT)
	OS +=WIN32
	ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
		OS +=_AMD64
	endif
	ifeq ($(PROCESSOR_ARCHITECTURE),x86)
		OS +=_IA32
	endif
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		OS+=LINUX
	endif
	ifeq ($(UNAME_S),Darwin)
		OS+=OSX
	endif
		UNAME_P := $(shell uname -p)
	ifeq ($(UNAME_P),x86_64)
		OS +=_AMD64
	endif
		ifneq ($(filter %86,$(UNAME_P)),)
			OS+=_IA32
		endif
	ifneq ($(filter arm%,$(UNAME_P)),)
		OS+=_ARM
	endif
endif

help:
	@echo ""
	@echo "Usage: make [command]"
	@echo ""
	@echo "Commands:"
	@echo "  test                     Run the tests"
	@echo "  test/list                List all tests under the tests directory"
	@echo "  test/watch               Automatically run tests every second"
	@echo "  docker/alpine            Run into a Docker Linux/Alpine:latest image"
	@echo "  env/example              Copy variables without the values from .env into .env.example"
	@echo "  pre_commit/install       Install the pre-commit hook"
	@echo "  pre_commit/run           Function that will be called when the pre-commit hook runs"
	@echo "  sa                       Run shellcheck static analysis tool"
	@echo "  lint                     Run editorconfig linter tool"

SRC_SCRIPTS_DIR=src
TEST_SCRIPTS_DIR=tests
EXAMPLE_TEST_SCRIPTS=./example/logic_test.sh
PRE_COMMIT_SCRIPTS_FILE=./bin/pre-commit

TEST_SCRIPTS = $(wildcard $(TEST_SCRIPTS_DIR)/*/*[tT]est.sh)

test/list:
	@echo "Test scripts found:"
	@echo $(TEST_SCRIPTS) | tr ' ' '\n'

test: $(TEST_SCRIPTS)
	@./bashunit $(TEST_SCRIPTS) -e tests/globals.sh

test/watch: $(TEST_SCRIPTS)
	@./bashunit $(TEST_SCRIPTS)
	@fswatch -m poll_monitor -or $(SRC_SCRIPTS_DIR) $(TEST_SCRIPTS_DIR) .env Makefile | xargs -n1 ./bashunit $(TEST_SCRIPTS)

docker/alpine:
	@docker run --rm -it -v "$(shell pwd)":/project -w /project alpine:latest \
		sh -c  "apk add bash make shellcheck git && bash"

env/example:
	@echo "Copying variables without the values from .env into .env.example"
	@sed 's/=.*/=/' .env > .env.example

pre_commit/install:
	@echo "Installing pre-commit hook"
	cp $(PRE_COMMIT_SCRIPTS_FILE) $(GIT_DIR)/hooks/

pre_commit/run: test sa lint env/example

sa:
ifndef STATIC_ANALYSIS_CHECKER
	@printf "\e[1m\e[31m%s\e[0m\n" "Shellcheck not installed: Static analysis not performed!" && exit 1
else
	@find . -name "*.sh" -not -path "./local/*" | xargs shellcheck -xC && printf "\e[1m\e[32m%s\e[0m\n" "ShellCheck: OK!"
endif

lint:
ifndef LINTER_CHECKER
	@printf "\e[1m\e[31m%s\e[0m\n" "Editorconfig not installed: Lint not performed!" && exit 1
else
	@ec -config .editorconfig && printf "\e[1m\e[32m%s\e[0m\n" "editorconfig-check: OK!"
endif
