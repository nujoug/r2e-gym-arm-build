#!/usr/bin/env bash
#
# build_pandas_three_combos.sh
#
# Tries three different sets of pinned Python/NumPy/Cython/etc. versions
# to build (and import) pandas. Exits on the first combination that succeeds.

set -e

VERSIONEER_COMMAND='echo -e "[versioneer]\nVCS = git\nstyle = pep440\nversionfile_source = pandas/_version.py\nversionfile_build = pandas/_version.py\ntag_prefix =\nparentdir_prefix = pandas-" > setup.cfg && versioneer install'

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  BUILD_CFLAGS="-O0 -Wno-error -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types -DNUMPY_IMPORT_ARRAY_RETVAL=NULL"
  echo "[INFO] Detected ARM64 ($ARCH) -- using relaxed CFLAGS: $BUILD_CFLAGS"

  # Neutralise -Werror in setup.py: pandas adds -Werror to extension compile
  # args (especially for vendored ujson). On ARM64, GCC warns about the
  # x86-only 'fastcall' attribute in ujson, and -Werror turns that into a
  # fatal error. Our CFLAGS -Wno-error is overridden because setup.py
  # appends -Werror last. Replacing with -Wno-error preserves list syntax.
  if [ -f setup.py ]; then
    sed -i 's/-Werror/-Wno-error/g' setup.py
    echo "[INFO] Replaced -Werror with -Wno-error in setup.py for ARM64 compatibility"
  fi
else
  BUILD_CFLAGS="-O0 -Wno-error=array-bounds"
fi
export CFLAGS="${BUILD_CFLAGS}"

build_and_check_pandas() {
  local python_ver="$1"
  local numpy_expr="$2"
  local cython_expr="$3"
  local setuptools_expr="$4"
  local versioneer_expr="$5"

  echo ""
  echo "[INFO] Creating new virtual environment with Python ${python_ver} ..."
  rm -rf .venv
  uv venv --python "${python_ver}"

  source .venv/bin/activate

  echo "[INFO] Upgrading pip and wheel ..."
  uv pip install --upgrade pip wheel

  echo "[INFO] Installing pinned dependencies ..."
  uv pip install --upgrade \
    "setuptools==${setuptools_expr}" \
    "numpy==${numpy_expr}" \
    "cython${cython_expr}" \
    "versioneer==${versioneer_expr}" \
    python-dateutil pytz pytest hypothesis jinja2

  if [ -f requirements-dev.txt ]; then
    uv pip install -r requirements-dev.txt || echo "[WARN] Some requirements-dev.txt deps failed to install (non-fatal)"
  fi

  echo "[INFO] Running versioneer setup ..."
  bash -c "set -e; source .venv/bin/activate && ${VERSIONEER_COMMAND}"

  echo "[INFO] Removing pyproject.toml if present (for older builds) ..."
  rm -f pyproject.toml

  echo "[INFO] Cleaning pandas build ..."
  uv run python setup.py clean --all

  echo "[INFO] Building pandas with CFLAGS='${BUILD_CFLAGS}' ..."
  CFLAGS="${BUILD_CFLAGS}" uv run python setup.py build_ext --inplace -j 4

  echo "[INFO] Installing pandas in editable mode ..."
  uv run pip install -e . --no-build-isolation

  echo "[INFO] Checking import of pandas ..."
  if ! .venv/bin/python -c "import pandas; print('Pandas version:', pandas.__version__); print(pandas.DataFrame([[1,2,3]]))"; then
    echo "[ERROR] Pandas import failed!"
    return 1
  fi

  echo "[SUCCESS] Build and import succeeded with Python=${python_ver}, NumPy=${numpy_expr}, Cython${cython_expr}."
}

########################
# Attempt #1
########################
echo "[Attempt #1] Trying Python=3.7, NumPy=1.17.*, Cython<0.30, setuptools=62.*, versioneer=0.23"
if build_and_check_pandas "3.7" "1.17.*" "<0.30" "62.*" "0.23"; then
  echo "[INFO] First combo succeeded. Exiting."
  exit 0
fi

########################
# Attempt #2
########################
echo "[Attempt #2] Trying Python=3.8, NumPy=1.20.*, Cython<0.30, setuptools=62.*, versioneer=0.23"
if build_and_check_pandas "3.8" "1.20.*" "<0.30" "62.*" "0.23"; then
  echo "[INFO] Second combo succeeded. Exiting."
  exit 0
fi

########################
# Attempt #3
########################
echo "[Attempt #3] Trying Python=3.9, NumPy=1.22.*, Cython==0.29.36, setuptools=62.*, versioneer=0.23"
if build_and_check_pandas "3.9" "1.22.*" "==0.29.36" "62.*" "0.23"; then
  echo "[INFO] Third combo succeeded. Exiting."
  exit 0
fi

########################
# Attempt #4
########################
echo "[Attempt #4] Trying Python=3.10, NumPy=1.26.*, Cython===3.0.5, setuptools=62.*, versioneer=0.23"
if build_and_check_pandas "3.10" "1.26.*" "===3.0.5" "62.*" "0.23"; then
  echo "[INFO] Fourth combo succeeded. Exiting."
  exit 0
fi

########################
# If none succeeded
########################
echo "[ERROR] All attempts failed."
exit 1
