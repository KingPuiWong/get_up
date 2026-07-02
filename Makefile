SWIFTC ?= swiftc
APP_NAME ?= GetUp
SOURCE_DIR := Sources/$(APP_NAME)
DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
BINARY := $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
DMG_STAGING := $(DIST_DIR)/dmg
DMG_PATH := $(DIST_DIR)/$(APP_NAME).dmg

.PHONY: build app dmg run clean

build: $(BINARY)

$(BINARY): $(SOURCE_DIR)/main.swift $(SOURCE_DIR)/AppDelegate.swift $(SOURCE_DIR)/Info.plist $(SOURCE_DIR)/icon.icns
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	$(SWIFTC) -framework ServiceManagement -o "$(BINARY)" "$(SOURCE_DIR)/main.swift" "$(SOURCE_DIR)/AppDelegate.swift"
	cp "$(SOURCE_DIR)/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	cp "$(SOURCE_DIR)/icon.icns" "$(APP_BUNDLE)/Contents/Resources/icon.icns"
	@echo "Built $(APP_BUNDLE)"

app: build

dmg: app
	rm -rf "$(DMG_STAGING)"
	mkdir -p "$(DMG_STAGING)"
	cp -R "$(APP_BUNDLE)" "$(DMG_STAGING)/"
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_PATH)"
	@echo "DMG created at $(DMG_PATH)"

run: build
	killall $(APP_NAME) 2>/dev/null || true
	open "$(APP_BUNDLE)"

clean:
	rm -rf "$(DIST_DIR)"
