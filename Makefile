# import config.
# You can change the default config with `make cnf="config_special.env" build`
cnf ?= config.env
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))

.PHONY: all test clean

test:
	echo "Running tests"
	mix test

test-watch:
	echo "Running test watch"
	mix test.watch

 compose-up:
	docker compose up