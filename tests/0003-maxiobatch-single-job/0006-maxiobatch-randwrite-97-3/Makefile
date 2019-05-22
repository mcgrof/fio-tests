all: default

.PHONY: default clean mrproper

TOPDIR=$(CURDIR)/../../../
-include $(TOPDIR)/.config

export TOPDIR

TEMPLATE=$(TOPDIR)/templates/0001-basic-template.ini.in

default: $(TEMPLATE)
	@echo Generating 97 % read / 3 % write single job max io batch submit range random write files...
	@$(TOPDIR)/scripts/gen-fio-files.sh \
		--rw randrw \
		--rwmixread 97 \
		--template-file $(TEMPLATE) \
		-b $(CONFIG_DUT_BLOCKSIZE) \
		-j 1 \
		-s $(CONFIG_DUT_IOSIZE) \
		--iodepth $(CONFIG_DUT_FOCUS_IODEPTH) \
		-f $(CONFIG_DUT_FILENAME) \
		-r $(CONFIG_DUT_RUNTIME) \
		--iodepth_batch_submit $(CONFIG_DUT_FOCUS_IODEPTH_BATCH_SUBMIT) \
		--iodepth_batch_complete_min $(CONFIG_DUT_IODEPTH_BATCH_COMPLETE_MIN) \
		--iodepth_batch_complete_max $(CONFIG_DUT_IODEPTH_BATCH_COMPLETE_MAX) \
		--min-iodepth $(CONFIG_DUT_TEST_MIN_IODEPTH) \
		--max-iodepth $(CONFIG_DUT_TEST_MAX_IODEPTH)

csv: *.res
	@$(TOPDIR)/scripts/gen-sheet.sh -d $(CURDIR)

ssv: *.res
	@$(TOPDIR)/scripts/gen-sheet.sh -f ssv -d $(CURDIR)

graph: *.ssv
	@$(TOPDIR)/scripts/gen-graph.sh -d $(CURDIR)

clean:
	rm -f *.ini

mrproper: clean;
