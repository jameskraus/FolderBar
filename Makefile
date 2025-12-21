APP_NAME := FolderBar
APP_PATH := build/$(APP_NAME).app
PACKAGE_SCRIPT := Scripts/package_app.sh
CONFIG ?= debug

.PHONY: build package run dev

build:
	swift build -c $(CONFIG)

package:
	CONFIG=$(CONFIG) $(PACKAGE_SCRIPT)

run: package
	open "$(APP_PATH)"

dev: run
