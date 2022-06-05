# Copyright 2019-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: yarn.eclass
# @MAINTAINER:
# Chris Pritchard <chris@christopherpritchard.co.uk>
# @AUTHOR:
# Chris Pritchard <chris@christopherpritchard.co.uk>
# William Hubbs <williamh@gentoo.org>
# Robin H. Johnson <robbat2@gentoo.org>
# @SUPPORTED_EAPIS: 7 8
# @BLURB: basic eclass for building software using a yarn lockfile
# @DESCRIPTION:
# This eclass provides basic settings and functions needed by all software
# written using node that uses a yarn lockfile. Based heavily off the go eclass.
#
# If the software you are packaging  has a file named yarn.lock in its top
# level directory, it uses yarn and  your ebuild should inherit this
# eclass. If it does not, you are on your own.
#
# Since yarn programs also include their modules, it is important that your ebuild's
# LICENSE= setting includes the licenses of all statically linked
# dependencies. So please make sure it is accurate.
#
# @EXAMPLE:
#
# @CODE
#
# inherit yarn
#
# EYARN_LOCK=(
#	'resolved "https://registry.yarnpkg.com/yargs/-/yargs-8.0.2.tgz#6299a9055b1cefc969ff7e79c1d918dceb22c360"'
#	'resolved "https://registry.yarnpkg.com/yn/-/yn-3.1.1.tgz#1e87401a09d767c1d5eab26a6e4c185182d2eb50"'
#	'resolved "https://registry.yarnpkg.com/yup/-/yup-0.32.8.tgz#16e4a949a86a69505abf99fd0941305ac9adfc39"'
# )
#
# yarn_set_globals
#
# SRC_URI="https://github.com/example/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
#		   ${EYARN_LOCK_SRC_URI}"
#
# @CODE

case ${EAPI:-0} in
	7) ;;
	8) ;;
	*) die "${ECLASS} EAPI ${EAPI} is not supported."
esac

if [[ -z ${_YARN_PACKAGE} ]]; then

_YARN_PACKAGE=1



# Workaround for pkgcheck false positive: https://github.com/pkgcore/pkgcheck/issues/214
# MissingUnpackerDep: version ...: missing BDEPEND="app-arch/unzip"
# Added here rather than to each affected package, so it can be cleaned up just
# once when pkgcheck is improved. Also depend on node and yarn.
BDEPEND+=" app-arch/unzip >=sys-apps/yarn-1.22.4  net-libs/nodejs"
# Allow packages to use node-gyp to build by including the installed version in ${PATH}
# Packages using node-gyp can use the node-headers included with the system install of nodejs.
PATH+=":/usr/lib64/node_modules/npm/bin/node-gyp-bin"
export npm_config_nodedir=/usr/include/node/

# Set the default cache and offline mirror directory for yarn
export YARN_CACHE_FOLDER="${T}/yarn-build"
export YARN_OFFLINE_MIRROR="${T}/yarn-offline"
export YARN_RC="${T}/yarnrc"

# The following yarn flags should be used for all builds.
# --offline uses packages in the local cache and causes an error if they are not available
# --verbose outputs verbose messages
# --frozen-lockfile doesn't generate a lockfile, and causes a failure 
# --use-yarnrc allows us to use a custom offline mirror created in src_unpack
export YARNFLAGS="--offline --verbose --frozen-lockfile --use-yarnrc=${YARN_RC}"

# Do not complain about CFLAGS etc since yarn projects do not use them.
QA_FLAGS_IGNORED='.*'

# js packages should not be stripped with strip(1).
RESTRICT+=" strip"

EXPORT_FUNCTIONS src_unpack pkg_postinst

# @ECLASS-VARIABLE: EYARN_LOCK
# @DESCRIPTION:
# This is an array based on the yarn.lock content from inside the target package.
# Each array entry must be quoted and contain information from a resolved line from yarn.lock.
#
# The format of yarn.lock is described upstream here:
# https://classic.yarnpkg.com/en/docs/yarn-lock/
#
# For inclusion in EYARN_LOCK, only the "resolved" line should be included
# you can run:
#	sed -n -e 's/^ *//g' -e "s/\(.*\)/'\1'/" -e '/resolved "/p' yarn.lock
# to obtain the correct information to include in EYARN_LOCK
# This decision  does NOT weaken yarn security, as yarn will verify the
# yarn.lock copy of the checksum values during building of the package.

# @ECLASS-VARIABLE: _YARN_REVERSE_MAP
# @DESCRIPTION:
# Mapping back from Gentoo distfile name to upstream archive name.
# Associative array
declare -A -g _YARN_ARCHIVE_MAP

# @FUNCTION: yarn_set_globals
# @DESCRIPTION:
# Convert the information in EYARN_LOCK for other usage in the ebuild.
# - Populates EYARN_LOCK_SRC_URI that can be added to SRC_URI

yarn_set_globals() {
	#local line exts
	# for tracking yarn.lock errors
	local error_in_yarnlock=0
	local yarn_prefix="yarn-"
	local -a yarnlock_errorlines
	# used make SRC_URI easier to read
	local newline=$'\n'

	# Now parse EYARN_LOCK
	for line in "${EYARN_LOCK[@]}"; do
		local resolved url checksum url_checksum archive fn misc x y z
		read -r resolved url_checksum <<< ${line}
		#remove quotes from the url
		url_checksum="${url_checksum%\"}"
		url_checksum="${url_checksum#\"}"

		# split the URL and checksum
		IFS=\# read -r url checksum x <<<"${url_checksum}"
		# if the package is in a scope (@) then name the package according to yarn conventions
		if [[ "${url}" == *"/@"*"/-/"* ]]; then
			local scope scope_subst_start scope_subst_end scope_num_chars
			scope_subst_start="${url%*'/@'*}"
			scope_subst_start_chars=$((${#scope_subst_start}+1))
			scope_subst_end=${url:scope_subst_start_chars}
			scope="${scope_subst_end%%'/'*}"
			fn="${scope}-${url##*/}"
		else
			fn="${url##*/}"
		fi
		# add a prefix to packages downloaded for yarn to allow reuse from distfiles but avoid conflict with portage downloads
		archive=${yarn_prefix}${fn}
		EYARN_LOCK_SRC_URI+="${url} -> ${archive}${newline}"
		_YARN_ARCHIVE_MAP["${archive}"]="${fn}"

		# Reject multiple # symbols in the url
		if [[ -n ${x} ]] || [[ -n ${y} ]]; then
			error_in_yarnlock=1
			yarnlock_errorlines+=( "Bad version: ${url}" )
			continue
		fi
	done

	if [[ ${error_in_yarnlock} != 0 ]]; then
		eerror "Trailing information in EYARN_LOCK in ${P}.ebuild"
		for line in "${yarnlock_errorlines[@]}" ; do
			eerror "${line}"
		done
		die "Invalid EYARN_LOCK format"
	fi

	# Ensure these variables are not changed past this point
	readonly EYARN_LOCK
	readonly EYARN_LOCK_SRC_URI
	readonly _YARN_ARCHIVE_MAP
	# Set the guard that we are safe
	_YARN_SET_GLOBALS_CALLED=1
}

# @FUNCTION: yarn_src_unpack
# @DESCRIPTION:
# If EYARN_LOCK is set, download the base tarball(s) and put them in the cache
# - Otherwise do a normal unpack.
yarn_src_unpack() {
	if [[ "${#EYARN_LOCK[@]}" -gt 0 ]]; then
		_yarn_src_unpack_yarnlock
	else
		default
	fi
}

# @FUNCTION: _yarn_src_unpack_yarnlock
# @DESCRIPTION:
# Populate a directory hierarchy with distfiles from EYARN_LOCK and
# unpack the base distfiles.
#
# creates a yarnrc file to use the offline repository
_yarn_src_unpack_yarnlock() {
	# shellcheck disable=SC2120
	debug-print-function "${FUNCNAME}" "$@"

	if [[ ! ${_YARN_SET_GLOBALS_CALLED} ]]; then
		die "yarn_set_globals must be called in global scope"
	fi

	local yarnoffline_dir="${T}/yarn-offline"
	mkdir -p "${yarnoffline_dir}" || die

	# For each yarn distfile, look up where it's supposed to go, and
	# symlink into place.
	local f
	for f in ${A}; do
		yarn_fn="${_YARN_ARCHIVE_MAP["${f}"]}"
		if [[ -n "${yarn_fn}" ]]; then
			einfo linking ${f} to ${yarnoffline_dir}/${yarn_fn}
			ln -sf "${DISTDIR}"/"${f}" "${yarnoffline_dir}"/"${yarn_fn}"
		else
			unpack "$f"
		fi
	done
	einfo creating yarnrc
	echo "yarn-offline-mirror ${yarnoffline_dir}" >> ${YARN_RC}
}

yarn_live_download() {
	debug-print-function "${FUNCNAME}" "$@"

	# shellcheck disable=SC2086
	has live ${PROPERTIES} ||
		die "${FUNCNAME} only allowed in live ebuilds"
	[[ "${EBUILD_PHASE}" == unpack ]] ||
		die "${FUNCNAME} only allowed in src_unpack"
	[[ -d "${S}"/node_modules ]] &&
		die "${FUNCNAME} only allowed when node_modules is not included"

	pushd "${S}" >& /dev/null || die
	einfo creating yarnrc
	echo "yarn-offline-mirror ${yarnoffline_dir}" >> ${YARN_RC}
	echo "yarn-offline-mirror-pruning true" >> ${YARN_RC}
	einfo fetching packages
	yarn install --ignore-scripts --frozen-lockfile --verbose --modules-folder=yarn_tmp_mods --use-yarnrc=${YARN_RC} || die
	popd >& /dev/null || die
}

# @FUNCTION: yarn_pkg_postinst
# @DESCRIPTION:
# Display a warning about security updates for yarn programs.
yarn_pkg_postinst() {
	debug-print-function "${FUNCNAME}" "$@"
	[[ -n ${REPLACING_VERSIONS} ]] && return 0
	ewarn "${PN} is written in the javascript programming language."
	ewarn "${PN} uses yarn to manage dependencies"
	ewarn "Since dependencies are included within the package, security"
	ewarn "updates will be handled in individual packages and will be"
	ewarn "difficult for us to track as a distribution."
	ewarn "For this reason, please update any yarn packages asap when new"
	ewarn "versions enter the tree or go stable if you are running the"
	ewarn "stable tree."
}
fi
