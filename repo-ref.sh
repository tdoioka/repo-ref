#!/usr/bin/env bash
set -ueo pipefail
VERSION=0.1.0

# configurations
################################################################
if [ -z "${REPOREF_DIR:-}" ]; then
  REPOREF_DIR="$(git config --get reporef.root || true)"
  REPOREF_DIR="${REPOREF_DIR:-${HOME}/repo-refs}"
fi

REPOINIT=(repo init)
REPOSYNC=(repo sync)
readonly REPOREF_DIR VERSION REPOINIT REPOSYNC

# main
################################################################
___main() {
  local -r cmd="${1?To show usage run: \`${0##*/} help\`}"
  shift
  case "${cmd}" in
    help|mirror|init|dir|list|sync|syncall)
      "subcmd_${cmd}" "$@" ;;
    -h|--help)
      _help
      return 0
      ;;
    *)
      _help
      return 2
      ;;
  esac
}

# help command
################################################################
subcmd_help() {
  _help
}

_help() {
  local -r cmd="${0##*/}"
  cat << __eof__
USAGE:
    ${cmd} <help|list|sync|syncall>
    ${cmd} <mirror|init|dir> <repo-argumetns>
SUBCMD:
    reference management:
        mirror:  create reference or sync a reference.
        list:    show all managed reference paths.
        dir:     show a reference directory by arguments.
        syncall: sync all references.

    reference usage:
        init:    create repo with reference, if not reference exists call mirror subcmd.
        sync:    repo sync before sync reference.

    common:
        help:    show this help message.

VERSION: ${VERSION}
__eof__
}

# mirror command
################################################################
subcmd_mirror() {
  local INITARGS=() SYNCARGS=() URL BRANCH MANIFEST rd
  _parse_args "$@"
  rd="$(_get_refdir)"
  if ! _is_repo "${rd}"; then
    _info "init: ${rd}"
    _init_mirror "${rd}"
  fi
  _info "sync: ${rd}"
  _sync_mirror "${rd}"
}

# init command
################################################################
subcmd_init() {
  local INITARGS=() SYNCARGS=() URL BRANCH MANIFEST rd
  _parse_args "$@"
  rd="$(_get_refdir)"
  readonly rd INITARGS SYNCARGS URL BRANCH MANIFEST
  if ! _is_repo "${rd}"; then
    _warn "${rd} is not set up."
    _init_mirror "${rd}"
    _info "sync: ${rd}"
    _sync_mirror "${rd}"
  fi
  if [ "${#TREEONLYINITARGS[*]}" -ne 0 ]; then
    _warn "Ignored init options for create a reference: ${TREEONLYINITARGS[*]}"
  fi
  "${REPOINIT[@]}" "${INITARGS[@]}" "${TREEONLYINITARGS[@]}" --reference="${rd}"
}

# sync command
################################################################
subcmd_sync() {
  local repod rd
  if ! repod="$(_upsearch_repo "${PWD}")"; then
    _err "Current dir is not managed by repo."
    return 1
  fi
  rd="$(_get_repo_ref "${repod}")"
  if [ -n "${rd}" ]; then
    _info "sync mirror repo before sync work repo: ${rd}"
    _sync_mirror "${rd}"
  fi
  _info "sync work repo: ${repod}"
  "${REPOSYNC[@]}" "${@:--j1}"
}

# dir command
################################################################
subcmd_dir() {
  local INITARGS=() SYNCARGS=() URL BRANCH MANIFEST
  _parse_args "$@"
  _get_refdir
}

# syncall command
################################################################
subcmd_syncall() {
  make -k -j1 all -f <(_sync_mkfile "$@")
}

# list command
################################################################
subcmd_list() {
  _list_refs
}

# internal functions
################################################################
_parse_args() {
  INITARGS=()
  TREEONLYINITARGS=()
  SYNCARGS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -u|--manifest-url)    INITARGS+=("$1" "$2"); URL="$2";           shift;;
      --manifest-url=*)     INITARGS+=("$1");      URL="${1#*=}";;
      -b|--manifest-branch) INITARGS+=("$1" "$2"); BRANCH="$2";        shift;;
      --manifest-branch=*)  INITARGS+=("$1");      BRANCH="${1#*=}";;
      -m|--manifest-name)   INITARGS+=("$1" "$2"); MANIFEST="$2";      shift;;
      --manifest-name=*)    INITARGS+=("$1");      MANIFEST="${1#*=}";;
      -j|--jobs|--jobs-network|--jobs-checkout) SYNCARGS+=("$1" "$2"); shift;;
      --jobs=*|--jobs-network=*|--jobs-checkout=*) SYNCARGS+=("$1");;
      -g|--group|-p|--platform|--depth) TREEONLYINITARGS+=("$1" "$2"); shift;;
      --group=*|--platform=*|--depth=*) TREEONLYINITARGS+=("$1");;
      *) INITARGS+=("$1");;
    esac
    shift ||:
  done
  local ret=0
  if [ -z "${URL:-}" ]; then
    _err "url is not set or empty."
    ret=1
  fi
  if [ -z "${BRANCH:-}" ];then
    _warn "set branch: ${BRANCH:=default}"
  fi
  if [ -z "${MANIFEST:-}" ]; then
    _warn "set manifest: ${MANIFEST:=default.xml}"
  fi
  readonly INITARGS SYNCARGS URL BRANCH MANIFEST
  return "${ret}"
}

_get_refdir() {
  local urldir="${URL#*://}"
  # urldir="${urldir%/*}"
  echo "${REPOREF_DIR}/${urldir}/${BRANCH}/${MANIFEST%.*}"
}

_init_mirror() {
  if ! _is_repo "${1}" && [ -e "${1}/.repo" ]; then
    _warn "remove incomplete ${1}/.repo"
    rm -rf "${1}/.repo"
  fi
  (
    mkdir -p "${1}"
    cd "${1}"
    flock "${1}" "${REPOINIT[@]}" "${INITARGS[@]}" --mirror
  )
}

_sync_mirror() {
  (
    cd "${1}"
    flock "${1}" "${REPOSYNC[@]}" "${SYNCARGS[@]:--j1}"
  )
}

_upsearch_repo() {
  local cur
  cur="$(realpath "$1")"
  while [ -n "${cur}" ] && [ "/" != "${cur}" ]; do
    if _is_repo "${cur}"; then
      echo "${cur}"
      return 0
    fi
    cur="${cur%/*}"
  done
  return 1
}

_sync_mkfile() {
  local rd
  while read -r rd; do
    cat << __eof__
refdirs += ${rd}
${rd}: $(_get_repo_ref "${rd}" || true)
__eof__
  done < <(_list_refs)

  cat << __eof__
.PHONY: all \$(refdirs)
all: \$(refdirs)
\$(refdirs):; cd "\$@"; flock "\$@" ${REPOSYNC[@]} "${SYNCARGS[@]:--j1}"
__eof__
}

_list_refs() {
  find "${REPOREF_DIR}" -type d -name '*.git' -prune -o -name .repo -type d -print0 |
    xargs -r -0 dirname |
    while read -r dir; do
      if _is_repo "${dir}"; then
        echo "${dir}"
      fi
    done
}

_get_repo_ref() {
  git -C "${1}/.repo/manifests" config repo.reference
}

_is_repo() {
  test -f "${1}/.repo/manifest.xml"
}

# common functions
################################################################
_err() {
  echo "ERROR: $*" >&2
}
_warn() {
  echo "WARNING: $*" >&2
}
_info() {
  echo "INFO: $*" >&2
}

# entry point
################################################################
___main "$@"
