CFLAGS=-Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer
LXDIALOG := lxdialog/checklist.o lxdialog/inputbox.o lxdialog/menubox.o lxdialog/textbox.o lxdialog/util.o lxdialog/yesno.o
MCONF_DEPS := mconf.o zconf.tab.c $(LXDIALOG)

default: mconf

zconf.tab.c: zconf.y
	@bison -ozconf.tab.c -t -l zconf.y
	@flex -ozconf.lex.c -L zconf.l

conf: conf.o zconf.tab.o
	$(CC) -o conf $^

mconf_CFLAGS :=  $(shell test -f $(CURDIR)/.mconf-cfg && . $(CURDIR)/.mconf-cfg && echo $$cflags) -DLOCALE
mconf_LDFLAGS := $(shell test -f $(CURDIR)/.mconf-cfg && . $(CURDIR)/.mconf-cfg && echo $$libs)
mconf: CFLAGS += ${mconf_CFLAGS}

include $(CURDIR)/../Kbuild.include
# check if necessary packages are available, and configure build flags
define filechk_conf_cfg
	$(CURDIR)/$<
endef

.%conf-cfg: %conf-cfg.sh
	$(call filechk,conf_cfg)

mconf: .mconf-cfg conf mconf.o zconf.tab.c $(LXDIALOG)
	$(CC) -o mconf $(MCONF_DEPS) $(mconf_LDFLAGS)

.PHONY: help
help:
	@echo "menuconfig         - demos the menuconfig functionality"
	@echo "allyesconfig       - enables all bells and whistles"
	@echo "allnoconfig        - disables all bells and whistles"
	@echo "randconfig         - random configuration"
	@echo "oldconfig*         - Use and old existing .config configuration"
	@echo "defconfig*         - Use default configuration - currently provision for iops"
	@echo "defconfig-*        - Use a default config, pick one from defconfig directory"

.PHONY: clean
clean:
	@rm -f conf mconf conf *.o lxdialog/*.o *.o zconf.tab.c .mconf-cfg
	@rm -rf *.o.d
