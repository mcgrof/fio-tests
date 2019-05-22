PROJECT=fio-tests
VERSION = 0
PATCHLEVEL = 1
SUBLEVEL = 0
EXTRAVERSION = -rc1

all: ini

ifeq ($(V),1)
Q=
NQ=true
else
Q=@
NQ=echo
endif

ifeq ($(D),)
D := ./
endif

ifeq ($(DEV),)
	DEV=/dev/nvme0n1
endif

export DEV

TOPDIR=./

include scripts/kconfig.Makefile

INCLUDES = -I include/
CFLAGS += $(INCLUDES)

obj-y += tests/

include scripts/objects.Makefile

ini: $(all-subdirs) precondition;
clean: $(clean-subdirs);
csv: $(csv-subdirs);
ssv: $(ssv-subdirs);
graph: $(graph-subdirs);

precondition:
	$(Q)$(MAKE) -C pre-conditioning/ $@

check:
	@$(CURDIR)/scripts/run-all-fio.sh -c -d $(D)

run:
	$(Q)$(MAKE) -C pre-conditioning/ clean
	@$(CURDIR)/scripts/run-all-fio.sh -d $(D)

dryrun:
	$(Q)$(MAKE) -C pre-conditioning/ clean
	@$(CURDIR)/scripts/run-all-fio.sh -n -d $(D)

demo: tests-demo-results.tar.xz
	@tar Jxvf tests-demo-results.tar.xz

help:
	$(Q)$(MAKE) -s -f scripts/build.Makefile $@

mrproper: clean
	$(Q)$(MAKE) -C pre-conditioning/ $@
	$(Q)$(MAKE) -s -f scripts/build.Makefile clean
	$(Q)$(MAKE) -s -f scripts/build.Makefile $@
	$(Q)$(MAKE) -s -C tests/ mrproper
	@rm -rf logs

export TOPDIR
.PHONY: all precondition ini check run dryrun clean mrproper help demo $(PHONY)
