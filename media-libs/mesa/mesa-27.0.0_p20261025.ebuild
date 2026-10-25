# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..13} )

inherit meson python-any-r1 flag-o-matic git-r3 toolchain-funcs multilib-minimal

DESCRIPTION="Mesa fork nvgd: native OpenGL, NVK, direct GA107 NVDEC H.264/AV1/HEVC/VP9 + NVENC video"
HOMEPAGE="https://github.com/Geanziin/nvgd"
EGIT_REPO_URI="https://github.com/Geanziin/nvgd.git"
EGIT_COMMIT="3e60407914972ebddcfcf34458f44ff53bc326fc"

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
	sys-devel/llvm:=[${MULTILIB_USEDEP}]
	sys-devel/clang:=[${MULTILIB_USEDEP}]
"

RDEPEND="${COMMON_DEPEND}"

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
	>=dev-build/meson-1.3.0
	>=dev-build/ninja-1.8.2
	virtual/pkgconfig
	sys-devel/bison
	sys-devel/flex
	vulkan? (
		dev-util/glslang
		dev-util/spirv-tools
		dev-lang/rust
		dev-util/cbindgen
		dev-util/rust-bindgen
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
		-Dgallium-drivers=nouveau,r300,r600,radeonsi,iris,crocus,i915,svga,virgl,softpipe,llvmpipe,zink
		-Dgallium-extra-hud=true
		-Dgallium-rusticl=$(usex rusticl true false)
		-Dgallium-va=$(usex vaapi enabled disabled)
		-Dvideo-codecs=$(usex proprietary-codecs all default)
		-Dnouveau-nvenc=$(usex nvenc true false)
		-Dplatforms=$(usex X "x11," "")$(usex wayland "wayland" "")
		-Dvulkan-drivers=$(usex vulkan "nouveau,amd,intel,intel_hasvk,swrast,virtio" "")
		-Dvulkan-layers=$(usex vulkan "device-select,intel-nullhw,overlay,screenshot,vram-report-limit" "")
		-Dzstd=$(usex zstd enabled disabled)
		-Dbuild-tests=false
	)

	meson_src_configure
}
