APP_NAME := FolderBar
APP_PATH := build/$(APP_NAME).app
PACKAGE_SCRIPT := Scripts/package_app.sh
COMPILE_RUN_SCRIPT := Scripts/compile_and_run.sh
CONFIG ?= debug

.PHONY: build test package run compile_and_run dev readme_icon format format_check lint ci

build:
	swift build -c $(CONFIG)

test:
	swift test -c $(CONFIG)

package:
	CONFIG=$(CONFIG) $(PACKAGE_SCRIPT)

run: package
	open "$(APP_PATH)"

compile_and_run:
	$(COMPILE_RUN_SCRIPT) $(CONFIG)

dev: compile_and_run

readme_icon:
	Scripts/generate_readme_icon.sh

format:
	swiftformat .

format_check:
	swiftformat --lint .

lint:
	swiftlint --strict --config .swiftlint.yml

ci: build test format_check lint
