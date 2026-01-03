_replace_rust_flag() {
  [ -n "$1" ] || die
  replacement="${2:+\$1"$2"}"
  export RUSTFLAGS="$(echo "$RUSTFLAGS" | perl -pe "s@((?:^| +)-C *)$1(?= |\$)@$replacement@g")"
}
_replace_ld_flag() {
  [ -n "$1" ] || die
  replacement="${2:+\$1"$2"}"
  export LDFLAGS="$(echo "$LDFLAGS" | perl -pe "s@((?:^| +)-)$1(?= |\$)@$replacement@g")"
  export CGO_LDFLAGS="$LDFLAGS"
  replacement="${2:+\$1link-arg="$2"}"
  _replace_rust_flag "link-arg=-$1" "$replacement"
}

_replace_common_flag() {
  [ -n "$1" ] || die
  replacement="${2:+\$1"$2"}"
  export COMMON_FLAGS="$(echo "$COMMON_FLAGS" | perl -pe "s@((?:^| +)-)$1(?= |\$)@$replacement@g")"
  export CFLAGS="$(echo "$CFLAGS" | perl -pe "s@((?:^| +)-)$1(?= |\$)@$replacement@g")"
  export CXXFLAGS="$CFLAGS"
  export F77FLAGS="$COMMON_FLAGS"
  export FCFLAGS="$COMMON_FLAGS"
  export FFLAGS="$COMMON_FLAGS"
  export BINDGEN_CFLAGS="$CFLAGS"
  export CGO_CFLAGS="$CFLAGS"
  export CGO_CXXFLAGS="$CFLAGS"
  export CGO_FFLAGS="$COMMON_FLAGS"
}

_add_common_flag() {
  export COMMON_FLAGS="$COMMON_FLAGS $@"
  export CFLAGS="$CFLAGS $@"
  export CXXFLAGS="$CFLAGS"
  export F77FLAGS="$COMMON_FLAGS"
  export FCFLAGS="$COMMON_FLAGS"
  export FFLAGS="$COMMON_FLAGS"
  export BINDGEN_CFLAGS="$CFLAGS"
  export CGO_CFLAGS="$CFLAGS"
  export CGO_CXXFLAGS="$CFLAGS"
  export CGO_FFLAGS="$COMMON_FLAGS"
}

_add_ld_flag() {
  export LDFLAGS="$LDFLAGS $@"
  export CGO_LDFLAGS="$LDFLAGS"
  export RUSTFLAGS="$RUSTFLAGS $(printf -- '-C link-arg=%q' "$@")"
}

_has_feature() {
  [ -n "$1" ] || die
  echo "$FEATURES" | grep -qwPe "$1"
}
_has_use() {
  [ -n "$1" ] || die
  echo "$USE" | grep -qwPe "$1"
}
_pv() {
  echo "$PV" | perl -pe 's/(\d+(\.\d+){,2}).*/\1/'
}


if [[ $EBUILD_PHASE_FUNC == src* ]]; then
  if _has_feature ccache && ! _has_feature sccache && ! { echo "$CCACHE_DIR" | grep -qw "${CATEGORY}/${PN}" ;}; then
    # export CCACHE_DIR="/var/cache/ccache/${CATEGORY}/${PN}/$(_pv)/"
    export CCACHE_DIR="/var/cache/ccache/${CATEGORY}/${PN}"
    mkdir -p "$CCACHE_DIR" || die
  fi
  if _has_feature sccache && ! { echo "$SCCACHE_DIR" | grep -qw "${CATEGORY}/${PN}" ;}; then
    # export SCCACHE_DIR="/var/cache/sccache/${CATEGORY}/${PN}/$(_pv)"
    export SCCACHE_DIR="/var/cache/sccache/${CATEGORY}/${PN}"
    mkdir -p "$SCCACHE_DIR" || die
    export SCCACHE_CONF=/etc/sccache.conf
  fi
fi

if _has_feature default-ld; then
  _replace_ld_flag 'fuse-ld=(/[\w/]+/)?mold'
fi

if _has_feature gcc; then
    _replace_common_flag 'ftrapping-math'
    _replace_common_flag 'f(pass-)?plugin(=|\s+)\S+'
    _replace_common_flag 'mllvm(=|\s+)\S+'
    _replace_common_flag 'funified-lto'
    _replace_rust_flag 'linker=clang'

    if ! _has_feature no-lto; then
        _add_common_flag '-Werror=lto-type-mismatch'

        if _has_feature parallel-lto; then
            _replace_common_flag 'flto(=\w+)?' 'flto=auto'
            _replace_ld_flag 'flto(=\w+)?' 'flto=auto'
        else
            _add_ld_flag '-flto-partition=one'
        fi
    fi
else
    if _has_feature no-polyhedra; then
        _replace_common_flag 'f(pass-)?plugin(=|\s+)\S+'
        _replace_common_flag 'mllvm(=|\s+)\S+'
    fi

    if _has_feature parallel-lto; then
        _replace_common_flag 'flto(=\w+)?' 'flto=thin'
        _replace_ld_flag 'flto(=\w+)?' 'flto=thin'
    fi
fi

if _has_feature no-lto; then
    _replace_common_flag 'flto(=\w+)?'
    _replace_ld_flag 'flto(=\w+)?'
    _replace_common_flag 'Werror=odr'
    _replace_common_flag 'Werror=strict-aliasing'
    _replace_rust_flag 'lto(=\w+)?'
fi

if _has_feature parallel-lto; then
    if echo "$LDFLAGS" | grep -qw -- -fuse-ld=lld; then
        _add_ld_flag '-Wl,--lto-partitions=16'
    fi
    _replace_rust_flag 'codegen-units=1'
    _replace_rust_flag 'lto(=\w+)?' 'lto=thin'
fi


