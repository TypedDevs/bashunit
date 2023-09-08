SHELL=/bin/bash

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
	@echo "  list-tests               List all the test under the tests directory"
	@echo "  test                     Run the test"
	@echo "  test/watch               Automatically run the test every second"
	@echo "  shellcheck               Static analysis tool that will run on all .sh files"

# Directory where your tests scripts are located
SRC_SCRIPTS_DIR=src
TEST_SCRIPTS_DIR=tests

# Find all *_test.sh scripts in the specified directory
TEST_SCRIPTS = $(wildcard $(TEST_SCRIPTS_DIR)/*/*[tT]est.sh)

# Display the list of tests scripts found
list-tests:
	@echo "Test scripts found:"
	@echo $(TEST_SCRIPTS) | tr ' ' '\n'

# Run all tests scripts
test: $(TEST_SCRIPTS)
	./bashunit $(TEST_SCRIPTS)

test/watch: $(TEST_SCRIPTS)
	watch --color -n 1 ./bashunit $(TEST_SCRIPTS)

shellcheck:
	SHELLCHECK_FOLDER=$(shell echo $(OS) | tr -d '[:space:]')
	./bin/$(shell echo $(OS) | tr -d '[:space:]')/shellcheck ./**/**.sh -C


.PHONY: test list-tests
