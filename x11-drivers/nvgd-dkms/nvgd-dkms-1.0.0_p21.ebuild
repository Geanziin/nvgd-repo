# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 linux-mod-r1

DESCRIPTION="nvgd: Next-Gen NVIDIA Driver with GSP P0 Boost for Turing+ GPUs (GTX 16xx, RTX 20/30/40)"
HOMEPAGE="https://github.com/Geanziin/nvgd-dkms"
EGIT_REPO_URI="https://github.com/Geanziin/nvgd-dkms.git"
EGIT_BRANCH="main"
# Pinned to the committed driver HEAD. The wave-1 driver changes (device
# gating, r615 Ada backend, sysfs unlock state) are uncommitted in the lab
# until after review wave 3; update EGIT_COMMIT when they land.
EGIT_COMMIT="abfa47142b918b958c2f1f0a28fbe54c7d2fb8ce"

LICENSE="GPL-2 MIT"
SLOT="0"
KEYWORDS="~amd64"

IUSE="+dkms"

RDEPEND="
	sys-kernel/linux-firmware
	dkms? ( sys-kernel/dkms )
"
DEPEND="
	virtual/linux-sources
"

CONFIG_CHECK="DRM"

# gpu-unlock firmware (610.43.03), pinned like the driver
# (firmware_pins_610.h). Shipped in FILESDIR; verified per file in
# src_install — a mismatch fails the install, never silently.
GPU_UNLOCK_BLOBS="
	booter_load_ad102.bin
	booter_load_ga102.bin
	gsp_boot_ad102.bin
	gsp_boot_desc_ad102.bin
	gsp_boot_desc_ga102.bin
	gsp_boot_ga102.bin
	gsp_ga10x.bin
	v67-ad102-610.43.03-four-plm.bin
	v67-ga102-610.43.03.bin
"

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

	# Firmware do bootloader SEC2 GSP para Turing/Ampere/Ada.
	# Instalado como arquivo real nos dois caminhos: no Gentoo o
	# symlink ga107/gsp -> ../ga102/gsp do linux-firmware-nvidia pode
	# não existir, então não se depende dele (diferença documentada
	# em relação ao Arch, que instala só em ga107/gsp).
	if [[ -f "${FILESDIR}/sec2-bl-615.78.08.bin" ]]; then
		insinto /usr/lib/firmware/nvidia/ga102/gsp
		doins "${FILESDIR}/sec2-bl-615.78.08.bin"
		insinto /usr/lib/firmware/nvidia/ga107/gsp
		doins "${FILESDIR}/sec2-bl-615.78.08.bin"
	fi

	# Firmware do desbloqueio Tensor Core (610.43.03). Sem estes blobs
	# o driver cai no fallback suave (velocidade stock) sem erro.
	if [[ -f "${FILESDIR}/SHA256SUMS" ]]; then
		(cd "${FILESDIR}" && sha256sum -c SHA256SUMS) || die "gpu-unlock firmware hash mismatch"
	fi
	insinto /usr/lib/firmware/gpu-unlock/610.43.03
	local blob
	for blob in ${GPU_UNLOCK_BLOBS}; do
		[[ -f "${FILESDIR}/${blob}" ]] || die "missing gpu-unlock blob: ${blob}"
		doins "${FILESDIR}/${blob}"
	done

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
	elog "Firmware gpu-unlock 610.43.03 instalado em /usr/lib/firmware/gpu-unlock/610.43.03/."
}
