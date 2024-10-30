include .env

.EXPORT_ALL_VARIABLES:
MAKEFLAGS += --no-print-directory

default:
	@forge fmt && forge build

clean:
	@forge clean && make default

# Always keep Forge up to date
install:
	foundryup
	rm -rf node_modules
	pnpm i

test:
	@forge test

test-f-%:
	@FOUNDRY_MATCH_TEST=$* make test

test-c-%:
	@FOUNDRY_MATCH_CONTRACT=$* make test

simulate:
	@network=$$(echo "$*" | cut -d'-' -f1); \
	script_path="script/initial/Deploy.s.sol:Deploy"; \
	forge script $$script_path;

deploy:
	@network=$$(echo "$*" | cut -d'-' -f1); \
	script_path="script/initial/Deploy.s.sol:Deploy"; \
	forge script $$script_path --broadcast --slow --private-key $$PRIVATE_KEY; \

.PHONY: test coverage


# ./target/release/createxcrunch create3 --caller 0x606A503e5178908F10597894B35b2Be8685EAB90  --leading 6