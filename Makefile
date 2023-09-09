.PHONY: build install

build:
	clear
	zig build -freference-trace

install:
	zig build -Doptimize=ReleaseSafe
	./install.sh
