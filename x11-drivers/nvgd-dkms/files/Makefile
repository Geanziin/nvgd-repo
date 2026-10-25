KDIR ?= /lib/modules/$(shell uname -r)/build

default: modules

modules:
	$(MAKE) -C $(KDIR) M=$(CURDIR) NOUVEAU_LAB_PIN_GSP=y \
		KCFLAGS='-include $(CURDIR)/lab-uapi/nouveau_drm.h -I$(KDIR)/include/uapi/drm' modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean

modules_install:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules_install

.PHONY: default modules clean modules_install
