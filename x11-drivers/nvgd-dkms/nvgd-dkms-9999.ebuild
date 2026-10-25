# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 linux-mod-r1

DESCRIPTION="nvgd (live git): Next-Gen NVIDIA Driver with GSP P0 Boost for Turing+ GPUs (GTX 16xx, RTX 20/30/40)"
HOMEPAGE="https://github.com/Geanziin/nvgd-dkms"
EGIT_REPO_URI="https://github.com/Geanziin/nvgd-dkms.git"
EGIT_BRANCH="main"

LICENSE="GPL-2 MIT"
SLOT="0"
KEYWORDS=""

IUSE="+dkms"

RDEPEND="
	sys-kernel/linux-firmware
	dkms? ( sys-kernel/dkms )
"
DEPEND="
	virtual/linux-sources
"

CONFIG_CHECK="DRM"

pkg_setup() {
	linux-mod-r1_pkg_setup
}

src_prepare() {
	default
	mkdir -p "${WORKDIR}/build/lab-uapi" || die
	cp -r drivers/gpu/drm/nouveau/* "${WORKDIR}/build/" || die
	cp include/uapi/drm/nouveau_drm.h "${WORKDIR}/build/lab-uapi/" || die
	cp "${FILESDIR}/Makefile" "${WORKDIR}/build/" || die
	cp "${FILESDIR}/dkms.conf" "${WORKDIR}/build/" || die
}

src_compile() {
	if ! use dkms; then
		local modlist=(
			nouveau=video/drm/nouveau:"${WORKDIR}/build"
		)
		local MODULES_MAKEARGS=(
			KDIR="${KV_OUT_DIR}"
		)
		linux-mod-r1_src_compile
	fi
}

src_install() {
	if use dkms; then
		local dest="/usr/src/nvgd-${PV}"
		dodir "${dest}"
		cp -r "${WORKDIR}/build"/* "${ED}${dest}/" || die
	else
		linux-mod-r1_src_install
	fi

	# Firmware do bootloader SEC2 GSP para Turing/Ampere
	if [[ -f "${FILESDIR}/sec2-bl-615.78.08.bin" ]]; then
		insinto /usr/lib/firmware/nvidia/ga102/gsp
		doins "${FILESDIR}/sec2-bl-615.78.08.bin"
		insinto /usr/lib/firmware/nvidia/ga107/gsp
		doins "${FILESDIR}/sec2-bl-615.78.08.bin"
	fi

	# Blacklist do modulo padrao do kernel para carregar o nvgd
	insinto /etc/modprobe.d
	newins "${FILESDIR}/nvgd-blacklist-nouveau.conf" nvgd-blacklist-nouveau.conf
}

pkg_postinst() {
	if use dkms; then
		elog "Módulo instalado para DKMS em /usr/src/nvgd-${PV}."
		elog "Para compilar e instalar no kernel ativo:"
		elog "  dkms add -m nvgd -v ${PV}"
		elog "  dkms build -m nvgd -v ${PV}"
		elog "  dkms install -m nvgd -v ${PV}"
	else
		linux-mod-r1_pkg_postinst
	fi
}
