# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )

MULTILIB_COMPAT=( abi_x86_{32,64} )

inherit meson-multilib python-any-r1 flag-o-matic git-r3 toolchain-funcs

DESCRIPTION="Mesa fork nvgd: native OpenGL, NVK, direct GA107 NVDEC H.264/AV1/HEVC/VP9 + NVENC video"
HOMEPAGE="https://github.com/Geanziin/nvgd"
EGIT_REPO_URI="https://github.com/Geanziin/nvgd.git"
EGIT_BRANCH="main"
EGIT_COMMIT="8add12ea58e41df4b45510df54ba4512637d05f8"

SRC_URI="
	vulkan? (
		https://gitlab.freedesktop.org/virgl/venus-protocol/-/archive/v1.1.3/venus-protocol-v1.1.3.tar.gz
			-> venus-protocol-v1.1.3.tar.gz
	)
	https://static.crates.io/crates/syn/2.0.87/download
		-> syn-2.0.87.tar.gz
	https://static.crates.io/crates/unicode-ident/1.0.12/download
		-> unicode-ident-1.0.12.tar.gz
	https://static.crates.io/crates/quote/1.0.35/download
		-> quote-1.0.35.tar.gz
	https://static.crates.io/crates/proc-macro2/1.0.86/download
		-> proc-macro2-1.0.86.tar.gz
	https://static.crates.io/crates/paste/1.0.14/download
		-> paste-1.0.14.tar.gz
	https://static.crates.io/crates/rustc-hash/2.1.1/download
		-> rustc-hash-2.1.1.tar.gz
"

LICENSE="MIT LGPL-2.1+ SGI-B-2.0"
SLOT="0"
KEYWORDS="~amd64"

IUSE="
	+X +egl +gbm +gles2 +glvnd +proprietary-codecs +nvenc +vaapi
	+vulkan +wayland +zstd debug rusticl selinux test
"

REQUIRED_USE="
	egl? ( || ( X wayland gbm ) )
	gles2? ( egl )
	vaapi? ( || ( X wayland ) )
"

COMMON_DEPEND="
	>=x11-libs/libdrm-2.4.120[video_cards_nouveau,${MULTILIB_USEDEP}]
	>=dev-libs/expat-2.1.0-r3:=[${MULTILIB_USEDEP}]
	>=media-libs/libglvnd-1.3.2[X?,${MULTILIB_USEDEP}]
	sys-libs/zlib:=[${MULTILIB_USEDEP}]
	zstd? ( app-arch/zstd:=[${MULTILIB_USEDEP}] )
	X? (
		>=x11-libs/libX11-1.6.2[${MULTILIB_USEDEP}]
		>=x11-libs/libxshmfence-1.1[${MULTILIB_USEDEP}]
		>=x11-libs/libXext-1.3.2[${MULTILIB_USEDEP}]
		>=x11-libs/libXfixes-5.0[${MULTILIB_USEDEP}]
		>=x11-libs/libXrandr-1.3[${MULTILIB_USEDEP}]
		>=x11-libs/libxcb-1.13:=[${MULTILIB_USEDEP}]
	)
	wayland? (
		>=dev-libs/wayland-1.18.0[${MULTILIB_USEDEP}]
	)
	vaapi? (
		>=media-libs/libva-2.20.0:=[${MULTILIB_USEDEP}]
	)
	vulkan? (
		>=media-libs/vulkan-loader-1.3.250[${MULTILIB_USEDEP}]
	)
	llvm-core/llvm:=[${MULTILIB_USEDEP}]
	llvm-core/clang:=[${MULTILIB_USEDEP}]
"

RDEPEND="${COMMON_DEPEND}
	!media-libs/mesa
"

DEPEND="${COMMON_DEPEND}
	X? (
		x11-base/xorg-proto
	)
	wayland? (
		>=dev-libs/wayland-protocols-1.34
	)
"

BDEPEND="
	${PYTHON_DEPS}
	$(python_gen_any_dep '
		dev-python/mako[${PYTHON_USEDEP}]
		dev-python/ply[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
	')
	>=dev-build/meson-1.7.0
	>=dev-build/ninja-1.8.2
	virtual/pkgconfig
	sys-devel/bison
	sys-devel/flex
	vulkan? (
		dev-util/glslang
		dev-util/spirv-tools
		dev-lang/rust
		dev-util/cbindgen
		dev-util/bindgen
	)
"

python_check_deps() {
	python_has_version "dev-python/mako[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/ply[${PYTHON_USEDEP}]" &&
	python_has_version "dev-python/pyyaml[${PYTHON_USEDEP}]"
}

pkg_setup() {
	python-any-r1_pkg_setup
}

multilib_src_configure() {
	if use vulkan; then
		local venus_dir="${S}/subprojects/venus-protocol-1.1.3"
		local venus_tarball="${DISTDIR}/venus-protocol-v1.1.3.tar.gz"

		[[ -f "${venus_tarball}" ]] ||
			die "venus-protocol tarball not found: ${venus_tarball}"

		if [[ ! -f "${venus_dir}/meson.build" ]]; then
			rm -rf "${venus_dir}"
			mkdir -p "${venus_dir}" ||
				die "Failed to create ${venus_dir}"

			tar -xzf "${venus_tarball}" \
				-C "${venus_dir}" \
				--strip-components=1 ||
				die "Failed to extract venus-protocol"
		fi
	fi

	local crate
	local crate_tarball
	local packagecache="${S}/subprojects/packagecache"

	mkdir -p "${packagecache}" ||
		die "Failed to create Meson packagecache"

	for crate in \
		    syn-2.0.87 \
		    unicode-ident-1.0.12 \
		    quote-1.0.35 \
		    proc-macro2-1.0.86 \
		    paste-1.0.14 \
		    rustc-hash-2.1.1; do

		crate_tarball="${DISTDIR}/${crate}.tar.gz"

		[[ -f "${crate_tarball}" ]] ||
			die "Crate tarball not found: ${crate_tarball}"

		cp -f "${crate_tarball}" "${packagecache}/${crate}.tar.gz" ||
			die "Failed to cache ${crate}"
	done

	local emesonargs=(
		-Dprefix="${EPREFIX}/usr"
		-Dsysconfdir="${EPREFIX}/etc"
		-Dbuildtype=$(usex debug debug plain)
		-Db_ndebug=$(usex debug false true)
		-Db_lto=false
		-Degl=$(usex egl enabled disabled)
		-Dgbm=$(usex gbm enabled disabled)
		-Dgles1=disabled
		-Dgles2=$(usex gles2 enabled disabled)
		-Dglvnd=$(usex glvnd enabled disabled)
		-Dglx=$(usex X dri disabled)
		-Dllvm=enabled
		-Dshared-llvm=enabled
		-Dgallium-drivers=nouveau,svga,virgl,softpipe,llvmpipe,zink
		-Dgallium-extra-hud=true
		-Dgallium-rusticl=$(usex rusticl true false)
		-Dgallium-va=$(usex vaapi enabled disabled)
		-Dvideo-codecs=$(usex proprietary-codecs all default)
		-Dnouveau-nvenc=$(usex nvenc true false)
		-Dplatforms=$(usex X "x11," "")$(usex wayland "wayland" "")
		-Dvulkan-drivers=$(usex vulkan "nouveau,swrast,virtio" "")
		-Dvulkan-layers=$(usex vulkan "device-select,overlay,screenshot,vram-report-limit" "")
		-Dzstd=$(usex zstd enabled disabled)
		-Dbuild-tests=false
		--wrap-mode=default
	)

	local llvm_prefix="/usr/lib/llvm/23"
	[[ ! -d "${llvm_prefix}" ]] && llvm_prefix="$(ls -d /usr/lib/llvm/* 2>/dev/null | sort -V | tail -n 1)"
	local llvm_pc="${llvm_prefix}/$(get_libdir)/pkgconfig"
	[[ ! -d "${llvm_pc}" ]] && llvm_pc="${llvm_prefix}/lib64/pkgconfig"
	export PKG_CONFIG_PATH="${llvm_pc}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"

	meson_src_configure
}

multilib_src_compile() {
	meson_src_compile
}

multilib_src_install() {
	meson_src_install
}
