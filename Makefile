DEPS_DIR := deps
PLENARY := $(DEPS_DIR)/plenary.nvim

.PHONY: test deps

test: deps
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

deps: $(PLENARY)

$(PLENARY):
	mkdir -p $(DEPS_DIR)
	git clone --depth=1 https://github.com/nvim-lua/plenary.nvim $(PLENARY)

