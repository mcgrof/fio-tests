all: default

TOPDIR=$(CURDIR)/../../
-include $(TOPDIR)/.config

.PHONY: default check clean mrproper

PROJECTS=$(shell find ./* -maxdepth 0 -type d)

obj-$(CONFIG_PROFILE_SEQWRITE)			+= 0001-iobatch-write/
obj-$(CONFIG_PROFILE_SEQREAD)			+= 0002-iobatch-read/
obj-$(CONFIG_PROFILE_RANDWRITE)			+= 0003-iobatch-randwrite/
obj-$(CONFIG_PROFILE_RANDREAD)			+= 0004-iobatch-randread/
obj-$(CONFIG_PROFILE_RANDWRITE_70_30)		+= 0005-iobatch-randwrite-70-30/
obj-$(CONFIG_PROFILE_RANDWRITE_97_3)		+= 0006-iobatch-randwrite-97-3/

include $(TOPDIR)/scripts/objects.Makefile

default: $(all-subdirs);
check: $(subdir-y-check);
clean: $(clean-subdirs);
csv: $(csv-subdirs);
ssv: $(ssv-subdirs);
graph: $(graph-subdirs);

mrproper:
	@for i in $(PROJECTS); do make -C $$i clean; done
	@echo Wiped 0002-iobatch tests...
