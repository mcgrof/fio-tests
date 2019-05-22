# Generic rule, you can be more specific in your own makefiles.
%.o: %.c *.h
	$(NQ) ' CC $@'
	$(Q)$(CC) -c $(CPPFLAGS) $(CFLAGS) -o $@ $<

ifeq ($(V),1)
Q=
NQ=true
else
Q=@
NQ=echo
endif

SUBARCH := $(shell uname -m | sed -e s/i.86/x86/ -e s/x86_64/x86/ \
				  -e s/sun4u/sparc64/ \
				  -e s/arm.*/arm/ -e s/sa110/arm/ \
				  -e s/s390x/s390/ -e s/parisc64/parisc/ \
				  -e s/ppc.*/powerpc/ -e s/mips.*/mips/ \
				  -e s/sh[234].*/sh/ -e s/aarch64.*/arm64/ \
				  -e s/riscv.*/riscv/)

# Needed for defconfig
ARCH		?= $(SUBARCH)

export ARCH

# Capture directories on obj-y and remove their leading character
# We will use this to construct a subdir object target for each, and
# a respective clean target.
__subdir-y      := $(patsubst %/,%,$(filter %/, $(obj-y)))
subdir-y        += $(__subdir-y)
subdir-y       := $(sort $(subdir-y))

# Make a target rule for each subdir, so that we can later add to the obj-y
# target. The subdir-y-obs carries all subdirectory objects.
# If a subdir name dirname exists, we add dirname/dirname.o to the list of
# objects in subdir-y-objs
subdir-y-objs       := $(foreach t,$(subdir-y),$(addsuffix /$t.o,$(t)))

# Add a phony clean target, you'll need to add this as a dependency on the
# top level clean target.
clean-subdirs       := $(foreach t,$(subdir-y),$(addsuffix /.ignore-clean,$(t)))
PHONY += $(clean-subdirs)

# Remove all directories from obj-y
obj-y      := $(filter-out %/, $(obj-y))

# Add the directory objects now to obj-y
obj-y      := $(obj-y) $(subdir-y-objs)

# For each clean target add a clean rule.
$(clean-subdirs):
	$(Q)$(MAKE) -s -C $(CURDIR)/$(patsubst %/.ignore-clean,%,$@) clean V=$(V)

# For each subdirectory object target add a respective build target
# using a default target, by using the directory name only.
$(subdir-y-objs):
	$(Q)$(MAKE) -s -C $(CURDIR)/$(dir $@) V=$(V)

all-subdirs       := $(foreach t,$(subdir-y),$(addsuffix /.ignore-all,$(t)))
PHONY += $(all-subdirs)
$(all-subdirs):
	$(Q)$(MAKE) -s -C $(CURDIR)/$(patsubst %/.ignore-all,%,$@) V=$(V)

check-subdirs       := $(foreach t,$(subdir-y),$(addsuffix /.ignore-check,$(t)))
PHONY += $(check-subdirs)
$(check-subdirs):
	$(Q)$(MAKE) -s -C $(CURDIR)/$(patsubst %/.ignore-check,%,$@) clean V=$(V)

csv-subdirs       := $(foreach t,$(subdir-y),$(addsuffix /.ignore-csv,$(t)))
PHONY += $(csv-subdirs)
$(csv-subdirs):
	$(Q)$(MAKE) -s -C $(CURDIR)/$(patsubst %/.ignore-csv,%,$@) csv V=$(V)

ssv-subdirs       := $(foreach t,$(subdir-y),$(addsuffix /.ignore-ssv,$(t)))
PHONY += $(ssv-subdirs)
$(ssv-subdirs):
	$(Q)$(MAKE) -s -C $(CURDIR)/$(patsubst %/.ignore-ssv,%,$@) ssv V=$(V)

graph-subdirs       := $(foreach t,$(subdir-y),$(addsuffix /.ignore-graph,$(t)))
PHONY += $(graph-subdirs)
$(graph-subdirs):
	$(Q)$(MAKE) -s -C $(CURDIR)/$(patsubst %/.ignore-graph,%,$@) graph V=$(V)
