set -e

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  export CFLAGS="-O0 -Wno-error -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types"
  echo "[INFO] Detected ARM64 ($ARCH) -- using relaxed CFLAGS: $CFLAGS"
fi

MAX_RETRIES=3
retry() {
    local n=0
    until [ $n -ge $MAX_RETRIES ]; do
        "$@" && return 0
        n=$((n + 1))
        echo "[RETRY] Attempt $n/$MAX_RETRIES failed, retrying in 5s..."
        sleep 5
    done
    return 1
}

check_install() {
    echo "Verifying installation..."
    if python -c "import coverage; print('CoveragePy version:', coverage.__version__)"; then
        echo "✅ Installation successful!"
        return 0
    else
        echo "❌ Verification failed"
        return 1
    fi
}

try_install_python37() {
    echo "Attempting installation with Python 3.7..."
    uv venv --python 3.7 --clear
    source .venv/bin/activate

    retry uv pip install -r requirements/dev.pip
    uv pip install setuptools pytest
    uv pip install -e .
    uv run python igor.py zip_mods

    check_install
}

try_install_python39() {
    echo "Attempting installation with Python 3.9..."
    uv venv --python 3.9 --clear
    source .venv/bin/activate

    retry uv pip install -r requirements/dev.pip
    uv pip install setuptools pytest
    uv pip install -e .
    uv run python igor.py zip_mods

    check_install
}


try_install_python310() {
    echo "Attempting installation with Python 3.10..."
    uv venv --python 3.10 --clear
    source .venv/bin/activate

    retry uv pip install -r requirements/dev.pip
    uv pip install setuptools pytest
    uv pip install -e .
    uv run python igor.py zip_mods

    check_install
}


echo "Starting CoveragePy installation attempts..."

if try_install_python37; then
    echo "Successfully installed CoveragePy using Python 3.7"
    exit 0
fi

echo "Python 3.7 installation failed, trying Python 3.9..."

if try_install_python39; then
    echo "Successfully installed CoveragePy using Python 3.9"
    exit 0
fi

echo "Python 3.9 installation failed, trying Python 3.10..."

if try_install_python310; then
    echo "Successfully installed CoveragePy using Python 3.10"
    exit 0
fi

echo "All installation attempts failed"
exit 1
