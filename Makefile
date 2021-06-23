SBIN_DIR ?= /usr/sbin
USR_DIR ?= /usr
MC_SRV_USER ?= mirrorcache
MIRRORCACHE_DNS ?= 'DBI:Pg:database=mirrorcache'

mkfile_path := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

tar.xz:
	git archive --format=tar HEAD | xz > mirrorcache-0.1.tar.xz

install:
	for i in lib script templates assets sql; do \
		mkdir -p "${DESTDIR}"/usr/share/mirrorcache/$$i ;\
		[ ! -e $$i ] || cp -a $$i/* "${DESTDIR}"/usr/share/mirrorcache/$$i ;\
	done
	mkdir -p "${DESTDIR}"/usr/share/mirrorcache/assets/cache
	chmod +x "${DESTDIR}"/usr/share/mirrorcache/script/*
	install -d -m 755 "${DESTDIR}"/usr/lib/systemd/system
	for i in dist/systemd/*.service; do \
		install -m 644 $$i "${DESTDIR}"/usr/lib/systemd/system ;\
	done

setup_system_user:
	getent group nogroup > /dev/null || groupadd nogroup
	getent passwd ${MC_SRV_USER} > /dev/null || ${SBIN_DIR}/useradd -r -g nogroup -c "MirrorCache user" \
	       -d ${USR_DIR}/lib/ ${MC_SRV_USER} 2>/dev/null || :
	mkdir -p "${DESTDIR}"/usr/share/mirrorcache/assets/cache
	chown ${MC_SRV_USER} "${DESTDIR}"/usr/share/mirrorcache/assets/cache


setup_system_db:
	sudo -u postgres createuser mirrorcache
	sudo -u postgres createdb mirrorcache

setup_production_assets:
	cd "${DESTDIR}"/usr/share/mirrorcache/ && \
	    MOJO_MODE=production ${mkfile_path}/tools/generate-packed-assets

.PHONY: check-js-beautify
check-js-beautify:
	@which js-beautify >/dev/null 2>&1 || (echo "Command 'js-beautify' not found, can not execute JavaScript beautifier" && false)

.PHONY: tidy-js
tidy-js: check-js-beautify
	@# Fall back to find if there is no git, e.g. in package builds
	for i in $$(git ls-files "*.js" 2>/dev/null || find assets/javascripts/ -name '*.js'); do js-beautify ${JSBEAUTIFIER_OPTS} $$i > $$i.new; mv $$i.new $$i; done

.PHONY: tidy
tidy: tidy-js
	tools/tidy
