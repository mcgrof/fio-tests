all: default

TOPDIR=$(CURDIR)/../../
-include $(TOPDIR)/.config

.PHONY: default check clean mrproper

PROJECTS=$(shell find ./* -maxdepth 0 -type d)

obj-$(CONFIG_PROFILE_SEQWRITE)			+= 0001-seqwrite/
obj-$(CONFIG_PROFILE_SEQREAD)			+= 0002-seqread/
obj-$(CONFIG_PROFILE_RANDWRITE)			+= 0003-randwrite/
obj-$(CONFIG_PROFILE_RANDREAD)			+= 0004-randread/
obj-$(CONFIG_PROFILE_RANDWRITE_70_30)		+= 0005-randwrite-70-30/
obj-$(CONFIG_PROFILE_RANDWRITE_97_3)		+= 0006-randwrite-97-3/

include $(TOPDIR)/scripts/objects.Makefile

default: $(all-subdirs);
check: $(subdir-y-check);
clean: $(clean-subdirs);
csv: $(csv-subdirs);
ssv: $(ssv-subdirs);
graph: $(graph-subdirs);

mrproper:
	@for i in $(PROJECTS); do make -C $$i clean; done
	@echo Wiped 0001-basic-tests tests...
