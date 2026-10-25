NVIM ?= nvim
export NVIM_LOG_FILE ?= /tmp/fzf-lua-image.nvim.log

.PHONY: test test-lazy

test:
	$(NVIM) --headless -u NONE -i NONE -l tests/run.lua
	$(NVIM) --headless -u NONE -i NONE -l tests/startup.lua
	$(NVIM) --headless -u NONE -i NONE -l tests/picker.lua

test-lazy:
	$(NVIM) --headless -u NONE -i NONE -l tests/lazy.lua
