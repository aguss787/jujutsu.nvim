DEPS_DIR := deps
MINI_TEST := $(DEPS_DIR)/mini.test

.PHONY: test deps

deps: $(MINI_TEST)

$(MINI_TEST):
	mkdir -p $(DEPS_DIR)
	git clone --depth=1 https://github.com/echasnovski/mini.test $(MINI_TEST)

test: deps
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "lua MiniTest.run()" \
		-c "lua vim.cmd.qall()"
