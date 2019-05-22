# SPDX-License-Identifier: GPL-2.0
#
# Houses the targets which top level Makfiles can also define.
PHONY += clean
clean: $(clean-subdirs)
	$(MAKE) -C scripts/kconfig/ clean
	@rm -f *.o $(obj-y)

PHONY += mrproper
mrproper:
	@rm -rf $(CURDIR)/include/config/
	@rm -rf $(CURDIR)/include/generated/
	@rm -f .config

version-check: include/config/project.release
	@echo Version: $(PROJECTVERSION)
	@echo Release: $(PROJECTRELEASE)

PHONY += help
help:
	@echo "Configuration options"
	@$(MAKE) -s -C scripts/kconfig help
	@echo
	@echo "Defaults configs:"					;\
	(cd defconfigs ; for f in $$(ls) ; do				\
		echo "defconfig-$$f"					;\
	done )
	@echo
	@echo "Pre-run targets:"
	@echo "ini                - default - builds fio ini files"
	@echo
	@echo "Test run options"
	@echo "check              - verifies all ini files parse correctly"
	@echo "check D=test/path/ - verifies ini files in directory parse correctly"
	@echo "run                - run fio tests on all ini files"
	@echo "run D=test/path/   - run fio tests for all ini files in directory"
	@echo
	@echo "Test Post processing options"
	@echo "ssv                - generate ssv files from results"
	@echo "csv                - generate csv files from results - for graph target"
	@echo
	@echo "Cleaning"
	@echo "clean              - cleans all output files"
	@echo "mrproper           - cleans all output files and configuration"
	@echo
	@echo "Debugging"
	@echo "dryrun             - do not run but just pretend to"
	@echo "version-check      - demos version release functionality"

.PHONY: $(PHONY)
