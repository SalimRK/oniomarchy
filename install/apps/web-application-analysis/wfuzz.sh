# wfuzz — Web Application Analysis
#
# python-wxpython is wxfuzz's (wfuzz's GUI entry point) toolkit
# dependency, undeclared by the PKGBUILD and still undeclared in the
# packaged one — it is an optional GUI mode, not a runtime requirement of
# the CLI, so it is installed here with the app that needs it rather than
# forced on everyone by depends=(). Same reasoning as nikto.sh's
# perl-xml-writer. See notes/install-issues.md.
pkg_official python-wxpython

# Everything else this leaf used to do is gone (2026-09-06). It had three
# stacked repairs, and [oniomarchy]'s packaged wfuzz retires all three:
#
# 1/ A mise-poisoned shebang. wfuzz was first installed before
#    lib/clean-build-path.sh existed, so its entry points' shebangs were
#    baked to mise's Python. This leaf detected that by reading the real
#    entry points via `pacman -Ql` and forced `yay -S --rebuild`. Packages
#    are built in a clean chroot now — there is no mise on the build host
#    and nothing builds on the user's machine at all.
#
# 2/ `import pkg_resources` in helpers/file_func.py, used only by
#    get_filter_help_file(). Modern python-setuptools dropped the
#    pkg_resources module outright, so wfuzz (last real release 2020)
#    failed to import on every single invocation.
#
# 3/ Three broken relative imports in ui/gui/controller.py — genuine
#    upstream bugs that meant wxfuzz had evidently never run under Python
#    3's relative-import semantics.
#
# 2 and 3 were patched here by sed-ing the INSTALLED files, because yay
# resyncs its ~/.cache/yay/wfuzz checkout against the AUR on every build
# and silently discarded a patched PKGBUILD before prepare() ever ran.
# That was a workaround for yay's workflow, not the right place for the
# fix. The packaging repo vendors the PKGBUILD and builds it with
# makechrootpkg, so nothing resyncs it: both patches now live in a proper
# prepare(), applied to the source tree every build. Both are also worth
# reporting upstream — they are in the packaging repo's AUR-report queue.
pkg_repo wfuzz
