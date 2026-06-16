APP_NAME := NiceTextEditor
CONFIG := release
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
EXECUTABLE := .build/$(CONFIG)/$(APP_NAME)

.PHONY: run build app clean

run:
	swift run $(APP_NAME)

build:
	swift build -c $(CONFIG)

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp "$(EXECUTABLE)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(APP_DIR)/Contents/Info.plist"
	cp "Resources/$(APP_NAME).icns" "$(APP_DIR)/Contents/Resources/$(APP_NAME).icns"

clean:
	rm -rf .build "$(BUILD_DIR)"
