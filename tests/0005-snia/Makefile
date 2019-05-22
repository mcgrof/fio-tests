all: default

TOPDIR=$(CURDIR)/../../
-include $(TOPDIR)/.config

.PHONY: default check clean mrproper

PROJECTS=$(shell find ./* -maxdepth 0 -type d)

obj-$(CONFIG_SNIA_IOPS)				+= 0001-iops/
#obj-$(CONFIG_SNIA_THROUGHPUT)			+= 0002-throughput/
#obj-$(CONFIG_SNIA_LATENCY)			+= 0003-latency/

include $(TOPDIR)/scripts/objects.Makefile

default: $(all-subdirs);
check: $(subdir-y-check);
clean: $(clean-subdirs);
csv: $(csv-subdirs);
ssv: $(ssv-subdirs);
graph: $(graph-subdirs);

mrproper:
	@for i in $(PROJECTS); do make -C $$i mrproper; done
	@echo Wiped 0005-snia tests...
