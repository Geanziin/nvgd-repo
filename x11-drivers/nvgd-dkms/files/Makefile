KDIR ?= /lib/modules/$(shell uname -r)/build

# LLVM=1, like the Arch Makefile: the driver builds with clang/lld.
# The default/modules_install targets are kept for the linux-mod-r1
# non-DKMS path (Arch has no such path, hence no such targets there).
default: modules

modules:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=1 NOUVEAU_LAB_PIN_GSP=y \
		KCFLAGS='-include $(CURDIR)/lab-uapi/nouveau_drm.h -I$(KDIR)/include/uapi/drm' modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=1 clean

modules_install:
	$(MAKE) -C $(KDIR) M=$(CURDIR) LLVM=1 modules_install

.PHONY: default modules clean modules_install
