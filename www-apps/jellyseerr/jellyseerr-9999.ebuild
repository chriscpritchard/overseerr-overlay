# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
PYTHON_COMPAT=( python3_{10..11} )
inherit yarn systemd python-any-r1

RESTRICT+=" mirror"

if [[ ${PV} == *9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/Fallenbagel/jellyseerr"
else
	EYARN_LOCK=()
	yarn_set_globals
	KEYWORDS="~amd64"
	SRC_URI="https://github.com/Fallenbagel/jellyseerr/archive/refs/tags/v${PV}.tar.gz
		${EYARN_LOCK_SRC_URI}"
fi

DESCRIPTION="a software application for managing requests for your media library that support Jellyfin and Emby"
HOMEPAGE="https://github.com/Fallenbagel/jellyseerr"

LICENSE="MIT"
SLOT="0"
IUSE=""
DEPEND="acct-user/jellyseerr
	acct-group/jellyseerr
	media-libs/vips
	net-libs/nodejs
	sys-apps/yarn
	dev-db/sqlite:3"
BDEPEND="${DEPEND}
		${PYTHON_DEPS}"
RDEPEND="${DEPEND}"

src_unpack() {
	if [[ ${PV} == *9999 ]]; then
		git-r3_src_unpack
		yarn_live_download
	else
		yarn_src_unpack
	fi
}

src_compile() {
	export npm_config_sqlite=${get_libdir}
	export npm_config_build_from_source=true
	export CYPRESS_INSTALL_BINARY=0
	if [[ ${PV} == *9999 ]]; then
		export COMMIT_TAG=`git rev-parse HEAD`
		echo "{\"commitTag\": \"${COMMIT_TAG}\"}" > committag.json
	fi
	yarn ${YARNFLAGS} install|| die "yarn install failed"
	yarn ${YARNFLAGS} build|| die "build failed"
	yarn ${YARNFLAGS} install --production --ignore-scripts|| die "yarn install failed"
}

src_install() {
	dodoc README.md
	insinto /etc
	doins "${FILESDIR}/jellyseerr.conf"
	insinto /usr/lib/jellyseerr/
	doins -r dist
	doins -r .next
	doins -r node_modules
	doins -r public
	doins babel.config.js
	doins next.config.js
	doins overseerr-api.yml
	doins package.json
	doins postcss.config.js
	doins stylelint.config.js
	doins tailwind.config.js
	doins committag.json
	find "${D}/usr/lib/jellyseerr/.next" -type f -print0 | xargs -0 sed -i "s^${WORKDIR}/${P}/^/usr/lib/jellyseerr/^g"
	keepdir /var/lib/jellyseerr/.config/jellyseerr/db
	keepdir /var/lib/jellyseerr/.config/jellyseerr/logs
	fowners -R jellyseerr:jellyseerr /var/lib/jellyseerr/.config
	into /
	insinto /
	systemd_dounit "${FILESDIR}/jellyseerr.service"
	dosym "${EPREFIX}/var/lib/jellyseerr/.config/jellyseerr" /usr/lib/jellyseerr/config
}
