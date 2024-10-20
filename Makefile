include .env

.EXPORT_ALL_VARIABLES:
MAKEFLAGS += --no-print-directory

default:
	@forge fmt && forge build

clean:
	rm report.txt
	@forge clean && make default

# Always keep Forge up to date
install:
	foundryup
	rm -rf node_modules
	pnpm i

test:
	@forge test --match-contract LaPosteTest --match-test test_receiveMessage

test-f-%:
	@FOUNDRY_MATCH_TEST=$* make test

test-c-%:
	@FOUNDRY_MATCH_CONTRACT=$* make test

simulate:
	@network=$$(echo "$*" | cut -d'-' -f1); \
	script_path="script/Deploy.s.sol:Deploy"; \
	forge script $$script_path;

deploy:
	@network=$$(echo "$*" | cut -d'-' -f1); \
	script_path="script/Deploy.s.sol:Deploy"; \
	forge script $$script_path --broadcast --slow --private-key $$PRIVATE_KEY; \

.PHONY: test coverage