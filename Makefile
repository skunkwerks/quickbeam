.PHONY: all deps zig compile format format-check test native-build-test

all: compile

deps:
	mix deps.get

zig:
	mix qb.zig

compile:
	mix qb.compile

format:
	mix qb.format

format-check:
	mix qb.format.check

test:
	mix qb.test

native-build-test:
	mix qb.native_build_test
