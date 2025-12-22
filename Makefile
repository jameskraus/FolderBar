APP_NAME := FolderBar
APP_PATH := build/$(APP_NAME).app
PACKAGE_SCRIPT := Scripts/package_app.sh
COMPILE_RUN_SCRIPT := Scripts/compile_and_run.sh
CONFIG ?= debug

.PHONY: build package run compile_and_run dev format lint

build:
	swift build -c $(CONFIG)

package:
	CONFIG=$(CONFIG) $(PACKAGE_SCRIPT)

run: package
	open "$(APP_PATH)"

compile_and_run:
	$(COMPILE_RUN_SCRIPT) $(CONFIG)

dev: compile_and_run

format:
	swiftformat .

lint:
	swiftlint --strict --config .swiftlint.yml
