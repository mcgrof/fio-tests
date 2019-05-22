all: default

.PHONY: default clean mrproper

TOPDIR=$(CURDIR)/../../../
-include $(TOPDIR)/.config

export TOPDIR

TEMPLATE=$(TOPDIR)/templates/0001-basic-template.ini.in

default: $(TEMPLATE)
	@echo Generating 97/3 random write fio files...
	@$(TOPDIR)/scripts/gen-fio-files.sh \
		--rw randrw \
		--rwmixread 97 \
		--template-file $(TEMPLATE) \
		-b $(CONFIG_DUT_BLOCKSIZE) \
		-s $(CONFIG_DUT_IOSIZE) \
		-j 1 \
		--min-iodepth $(CONFIG_DUT_TEST_MIN_IODEPTH) \
		--max-iodepth $(CONFIG_DUT_TEST_MAX_IODEPTH) \
		-f $(CONFIG_DUT_FILENAME) \
		-r $(CONFIG_DUT_RUNTIME)

csv: *.res
	$(TOPDIR)/scripts/gen-sheet.sh -d $(CURDIR)

ssv: *.res
	$(TOPDIR)/scripts/gen-sheet.sh -f ssv -d $(CURDIR)

graph: *.ssv
	@$(TOPDIR)/scripts/gen-graph.sh -d $(CURDIR)

clean:
	@rm -f *.ini

mrproper: clean;
