SHELL=/bin/bash

include .env

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
	@echo "  env/example              Makes a copy of the keys on your .env file"
	@echo "  pre_commit/install       installs the pre-commit hook"
	@echo "  pre_commit/run           function that will be called when the pre-commit runs"

# Directory where your tests scripts are located
SRC_SCRIPTS_DIR=src
TEST_SCRIPTS_DIR=tests
PRE_COMMIT_SCRIPTS_FILE=./bin/pre-commit

# Find all test scripts in the specified directory
TEST_SCRIPTS = $(wildcard $(TEST_SCRIPTS_DIR)/*/*[tT]est.sh)

# Display the list of tests scripts found
test/list:
	@echo "Test scripts found:"
	@echo $(TEST_SCRIPTS) | tr ' ' '\n'

# Run all tests scripts
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

pre_commit/run: test env/example


.PHONY: test list-tests
