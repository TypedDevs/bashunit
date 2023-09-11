SHELL=/bin/bash

-include .env

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
	@echo "usage: make COMMAND"
	@echo ""
	@echo "Commands:"
	@echo "  test                     Run the test"
	@echo "  test/list                List all the test under the tests directory"
	@echo "  test/watch               Automatically run the test every second"
	@echo "  test/example             Run test from the example directory"
	@echo "  env/example              Makes a copy of the keys on your .env file"
	@echo "  pre_commit/install       Installs the pre-commit hook"
	@echo "  pre_commit/run           Function that will be called when the pre-commit runs"
	@echo "  lint                     Run shellcheck static analysis tool"

SRC_SCRIPTS_DIR=src
TEST_SCRIPTS_DIR=tests
EXAMPLE_TEST_SCRIPTS=./example/logic_test.sh
PRE_COMMIT_SCRIPTS_FILE=./bin/pre-commit

TEST_SCRIPTS = $(wildcard $(TEST_SCRIPTS_DIR)/*/*[tT]est.sh)

test/list:
	@echo "Test scripts found:"
	@echo $(TEST_SCRIPTS) | tr ' ' '\n'

test: $(TEST_SCRIPTS)
	./bashunit $(TEST_SCRIPTS)

test/watch: $(TEST_SCRIPTS)
	watch --color -n 1 ./bashunit $(TEST_SCRIPTS)

env/example:
	@echo "Copy the .env into the .env.example file without the values"
	@sed 's/=.*/=/' .env > .env.example

pre_commit/install:
	@echo "Installing pre-commit hooks"
	cp $(PRE_COMMIT_SCRIPTS_FILE) ./.git/hooks/

pre_commit/run: test lint env/example

lint:
	@shellcheck ./**/**/*.sh -C && printf "\e[1m\e[32m%s\e[0m\n" "Shellcheck: OK!"

test/example:
	@./bashunit $(EXAMPLE_TEST_SCRIPTS)
