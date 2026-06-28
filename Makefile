APP_NAME := homeboard
BUILD_DIR := build
ZIP_FILE := $(BUILD_DIR)/$(APP_NAME).zip
ROKU_DEV_TARGET ?=
ROKU_DEV_PASSWORD ?=

ROKU_FILES := manifest config.json source components images

.PHONY: zip deploy clean

zip: clean
	@mkdir -p $(BUILD_DIR)
	@zip -r $(ZIP_FILE) $(ROKU_FILES) -x "*.DS_Store"
	@echo "Created $(ZIP_FILE)"

deploy: zip
	@test -n "$(ROKU_DEV_TARGET)" || (echo "Set ROKU_DEV_TARGET, for example: make deploy ROKU_DEV_TARGET=192.168.1.50 ROKU_DEV_PASSWORD=..." && exit 1)
	@test -n "$(ROKU_DEV_PASSWORD)" || (echo "Set ROKU_DEV_PASSWORD" && exit 1)
	@curl --fail --show-error --user rokudev:$(ROKU_DEV_PASSWORD) --digest \
		-F "mysubmit=Install" -F "archive=@$(ZIP_FILE)" \
		http://$(ROKU_DEV_TARGET)/plugin_install
	@echo "Deployed $(ZIP_FILE) to $(ROKU_DEV_TARGET)"

clean:
	@rm -rf $(BUILD_DIR)
