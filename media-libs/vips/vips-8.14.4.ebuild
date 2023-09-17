# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit meson meson-multilib

DESCRIPTION="VIPS Image Processing Library"
SRC_URI="https://github.com/lib${PN}/lib${PN}/archive/v${PV//_rc/-rc}.tar.gz -> lib${P}.tar.gz"
HOMEPAGE="https://libvips.github.io/libvips/"

RESTRICT="mirror"
LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="doc debug exif fits fftw graphicsmagick imagemagick jpeg lcms matio openexr
	+orc png svg static-libs tiff webp"

RDEPEND="
	debug? ( dev-libs/dmalloc )
	>=dev-libs/glib-2.6:2
	dev-libs/libxml2
	sys-libs/zlib
	>=x11-libs/pango-1.8
	fftw? ( sci-libs/fftw:3.0= )
	imagemagick? (
		graphicsmagick? ( media-gfx/graphicsmagick )
		!graphicsmagick? ( media-gfx/imagemagick )
	)
	lcms? ( media-libs/lcms )
	svg? ( gnome-base/librsvg )
	matio? ( >=sci-libs/matio-1.3.4 )
	openexr? ( >=media-libs/openexr-1.2.2:* )
	exif? ( >=media-libs/libexif-0.6 )
	tiff? ( media-libs/tiff:0= )
	jpeg? ( virtual/jpeg:0= )
	fits? ( sci-libs/cfitsio )
	png? ( >=media-libs/libpng-1.2.9:0= )
	webp? ( media-libs/libwebp )
	orc? ( >=dev-lang/orc-0.4.11 )
"
DEPEND="
	${RDEPEND}
	dev-util/gtk-doc-am
	dev-util/gtk-doc
"

S="${WORKDIR}/lib${P//_rc/-rc}"

DOCS=(ChangeLog README.md)

#MULTILIB_WRAPPED_HEADERS=(
#	/usr/include/vips/version.h
#)

src_prepare() {
	sed -r \
		-e '/define VIPS_VERSION_STRING/s#@VIPS_VERSION_STRING@#@VIPS_VERSION@#' \
		-i "${S}"/libvips/include/vips/version.h.in || die

	default

	gtkdocize --copy --docdir doc --flavour no-tmpl
	# ^ the way portage calling it doesn't work, so let's call manually
}

multilib_src_configure() {
	local magick="-Dmagick=disabled"
	use imagemagick && magick="-Dmagick-package=MagickCore"
	use graphicsmagick && magick="-Dmagick-package=GraphicsMagick"

	local emesonargs=(
		${magick}
		$(meson_native_use_bool doc gtk_doc)
		$(meson_native_use_bool doc doxygen)
		$(meson_use debug)
                $(meson_feature fftw)
                $(meson_feature lcms)
                $(meson_feature openexr)
                $(meson_feature matio)
                $(meson_feature exif)
                $(meson_feature png)
                $(meson_feature svg rsvg)
                $(meson_feature tiff)
                $(meson_feature fits cfitsio)
                $(meson_feature jpeg)
                $(meson_feature orc)
                $(meson_feature webp)
	)
	meson_src_configure
}

multilib_src_install_all() {
	einstalldocs
	find "${D}" -xtype f -name '*.la' -print0
}
