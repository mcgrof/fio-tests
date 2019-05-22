all: precondition

TOPDIR=$(CURDIR)/../
-include $(TOPDIR)/.config

WI_DIR = 0001-workload-independent
WD_DIR = 0002-workload-dependent

PRECONDITION_FILES  = $(WI_DIR)/0001-pre-condition-sequential.ini

WORK_DIRS=$(shell find ./* -maxdepth 0 -type d)
SYMLINKS=$(shell find ./* -type l)

$(PRECONDITION_FILES):
	@$(TOPDIR)/scripts/gen-pre-condition.sh

precondition: $(PRECONDITION_FILES);

clean:
	@for i in $(WORK_DIRS); do rm -f $$i/*.{OK,BAD,TIME,res,out}; done

mrproper: clean
	@for i in $(WORK_DIRS); do rm -rf $$i; done
	@for i in $(SYMLINKS); do rm -rf $$i; done

.PHONY: clean mrproper precondition

export TOPDIR
