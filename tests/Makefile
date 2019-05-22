all: default

TOPDIR=$(CURDIR)/../
-include $(TOPDIR)/.config

.PHONY: default check clean mrproper

PROJECTS=$(shell find ./* -maxdepth 0 -type d)

obj-$(CONFIG_BASIC_TESTS)		+= 0001-basic-tests/
obj-$(CONFIG_IODEPTH_BATCH)		+= 0002-iobatch/
obj-$(CONFIG_MAX_IOBATCH_SINGLE)	+= 0003-maxiobatch-single-job/
obj-$(CONFIG_MAX_IOBATCH_JOBS)		+= 0004-maxiobatch-jobs/
obj-$(CONFIG_SNIA_TESTS)		+= 0005-snia/

include $(TOPDIR)/scripts/objects.Makefile

default: $(all-subdirs);
check: $(check-subdirs);
clean: $(clean-subdirs);
csv: $(csv-subdirs);
ssv: $(ssv-subdirs);
graph: $(graph-subdirs);

mrproper:
	@for i in $(PROJECTS); do make -C $$i mrproper; done
