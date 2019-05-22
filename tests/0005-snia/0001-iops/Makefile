all: default

.PHONY: default clean mrproper

TOPDIR=$(CURDIR)/../../../
-include $(TOPDIR)/.config

export TOPDIR

TEMPLATE_ID=$(TOPDIR)/templates/pre-condition/snia/0001-workload-independent-pre-condition.ini.in
TEMPLATE_WD=$(TOPDIR)/templates/pre-condition/snia/0002-workload-dependent-pre-condition.ini.in

default: $(TEMPLATE)
	@echo Generating SNIA IOPS workload independent test files ...
	@$(TOPDIR)/scripts/gen-fio-files.sh \
		--mode snia-wi \
		--iodepth $(CONFIG_SNIA_IOPS_IODEPTH) \
		-j $(CONFIG_SNIA_IOPS_JOBS) \
		-b $(CONFIG_SNIA_IOPS_WI_BS) \
		--loop $(CONFIG_SNIA_IOPS_WI_LOOPS) \
		--template-file $(TEMPLATE_ID) \
		--rw write \
		-f $(CONFIG_DUT_FILENAME) \
		-r $(CONFIG_SNIA_IOPS_ID_RUNTIME)
	@echo Generating SNIA IOPS workload dependent test files ...
	@$(TOPDIR)/scripts/gen-fio-files.sh \
		--mode snia-wd \
		--uses-fio-ss \
		--iodepth-step $(CONFIG_SNIA_IOPS_IODEPTH) \
		--job-step $(CONFIG_SNIA_IOPS_JOBS) \
		--randrw-step $(CONFIG_SNIA_IOPS_WD_RANDRW_STEP) \
		--bs-step $(CONFIG_SNIA_IOPS_WD_BS_STEP) \
		--template-file $(TEMPLATE_WD) \
		--sizeset $(CONFIG_SNIA_IOPS_ACTIVE_RANGE) \
		--ss-iops-mean-limit $(CONFIG_SNIA_IOPS_WD_SS_MEAN_LIMIT) \
		--ss-iops-mean-limit-dur $(CONFIG_SNIA_IOPS_WD_SS_MEAN_LIMIT_DUR) \
		--ss-iops-slope $(CONFIG_SNIA_IOPS_WD_SS_SLOPE) \
		--ss-iops-slope-dur $(CONFIG_SNIA_IOPS_WD_SS_SLOPE_DUR) \
		-f $(CONFIG_DUT_FILENAME) \
		-r $(CONFIG_SNIA_IOPS_WD_RUNTIME)

WORK_DIRS=$(shell find ./* -maxdepth 0 -type d)

csv: *.res
	@$(TOPDIR)/scripts/gen-sheet.sh -d $(CURDIR)

ssv: *.res
	@$(TOPDIR)/scripts/gen-sheet.sh -f ssv -d $(CURDIR)

graph: *.ssv
	@$(TOPDIR)/scripts/gen-graph.sh -d $(CURDIR)

clean:
	rm -f *.OK *.res *.out *.json *.TIME *.BAD
	@find ./ -name \*.ini | xargs rm -f

mrproper: clean;
	@for i in $(WORK_DIRS); do rm -rf $$i; done
