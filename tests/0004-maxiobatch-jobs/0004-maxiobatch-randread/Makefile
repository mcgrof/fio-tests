all: default

.PHONY: default clean mrproper

TOPDIR=$(CURDIR)/../../../
-include $(TOPDIR)/.config

export TOPDIR

TEMPLATE=$(TOPDIR)/templates/0001-basic-template.ini.in

default: $(TEMPLATE)
	@echo Generating io batch submit range random read files...
	@$(TOPDIR)/scripts/gen-fio-files.sh \
		--rw randread \
		--template-file $(TEMPLATE) \
		-b $(CONFIG_DUT_BLOCKSIZE) \
		-s $(CONFIG_DUT_IOSIZE) \
		--iodepth $(CONFIG_DUT_FOCUS_IODEPTH) \
		-f $(CONFIG_DUT_FILENAME) \
		-r $(CONFIG_DUT_RUNTIME) \
		--iodepth_batch_submit $(CONFIG_DUT_FOCUS_IODEPTH_BATCH_SUBMIT) \
		--iodepth_batch_complete_min $(CONFIG_DUT_IODEPTH_BATCH_COMPLETE_MIN) \
		--iodepth_batch_complete_max $(CONFIG_DUT_IODEPTH_BATCH_COMPLETE_MAX) \
		--min-iodepth $(CONFIG_DUT_TEST_MIN_FOCUS_IODEPTH) \
		--max-iodepth $(CONFIG_DUT_TEST_MAX_FOCUS_IODEPTH) \
		--min-jobs $(CONFIG_DUT_NUMJOBS_MIN) \
		--max-jobs $(CONFIG_DUT_NUMJOBS_MAX)

WORK_DIRS=$(shell find ./* -maxdepth 0 -type d)

csv:
	@for i in $(WORK_DIRS); do $(TOPDIR)/scripts/gen-sheet.sh -t -d $$i; done

ssv:
	@for i in $(WORK_DIRS); do $(TOPDIR)/scripts/gen-sheet.sh -t -f ssv -d $$i; done

graph:
	@for i in $(WORK_DIRS); do $(TOPDIR)/scripts/gen-graph.sh -t -d $$i; done

clean:
	@for i in $(WORK_DIRS); do rm -rf $$i; done

mrproper: clean;
