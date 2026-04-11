PYTHON ?= python3
VENV_DIR ?= .venv
VENV_PYTHON := $(VENV_DIR)/bin/python
VENV_PIP := $(VENV_PYTHON) -m pip
APP_NAME ?= GetUp
DIST_DIR := dist
DMG_STAGING := $(DIST_DIR)/dmg
DMG_PATH := $(DIST_DIR)/$(APP_NAME).dmg

.PHONY: venv deps test app dmg clean

venv:
	@test -x "$(VENV_PYTHON)" || $(PYTHON) -m venv "$(VENV_DIR)"

deps: venv
	$(VENV_PIP) install -r requirements-build.txt

test: deps
	$(VENV_PYTHON) -m unittest -v

app: clean test
	$(VENV_PYTHON) setup.py py2app

dmg: app
	rm -rf "$(DMG_STAGING)"
	mkdir -p "$(DMG_STAGING)"
	APP_PATH="$$(find "$(DIST_DIR)" -maxdepth 1 -name '*.app' -print -quit)"; \
	if [ -z "$$APP_PATH" ]; then \
		echo "No .app bundle found under $(DIST_DIR)."; \
		exit 1; \
	fi; \
	cp -R "$$APP_PATH" "$(DMG_STAGING)/"
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_PATH)"
	@echo "DMG created at $(DMG_PATH)"

clean:
	rm -rf build dist *.egg-info
