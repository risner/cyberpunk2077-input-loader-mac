.PHONY: release

APP = engine/tools/inputloader.pl

VER = $(shell awk -F\" '/MOD_VERSION_STR/ {print $$2}' $(APP))
VER != awk -F\" '/MOD_VERSION_STR/ {print $$2}' $(APP)

REL = input-loader-mac-v$(VER).zip

release:
	@echo Creating release $(REL)
	@rm -f $(REL)
	@zip -r $(REL) $(APP) engine/config/platform/mac/input_loader.ini launch_modded.sh r6/input/
