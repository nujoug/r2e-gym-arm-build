#!/bin/bash

set -e  # Exit on any error

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  export CFLAGS="-O0 -Wno-error -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types"
  echo "[INFO] Detected ARM64 ($ARCH) -- using relaxed CFLAGS: $CFLAGS"
fi

check_numpy() {
    echo "Verifying NumPy installation..."
    if .venv/bin/python -c "import numpy; numpy.array([1,2])" &> /dev/null; then
        echo "✅ NumPy installation successful!"
        return 0
    else
        echo "❌ NumPy verification failed"
        return 1
    fi
}


try_install_python37() {
    echo "Attempting installation with Python 3.7..."
    uv venv --python 3.7 --python-preference only-managed --clear
    source .venv/bin/activate
    uv pip install "setuptools<=59.8.0" "cython<0.30" pytest pytest-env hypothesis nose
    .venv/bin/python setup.py clean --all 2>/dev/null || true
    .venv/bin/python setup.py build_ext --inplace
    check_numpy
}

try_install_python38() {
    echo "Attempting installation with Python 3.8..."
    uv venv --python 3.8 --python-preference only-managed --clear
    source .venv/bin/activate
    uv pip install "setuptools<=59.8.0" "cython<0.30" pytest pytest-env hypothesis nose
    .venv/bin/python setup.py clean --all 2>/dev/null || true
    .venv/bin/python setup.py build_ext --inplace
    check_numpy
}

try_install_python39() {
    echo "Attempting installation with Python 3.9..."
    uv venv --python 3.9 --python-preference only-managed --clear
    source .venv/bin/activate
    uv pip install "setuptools<=59.8.0" "cython<0.30" pytest pytest-env hypothesis nose
    .venv/bin/python setup.py clean --all 2>/dev/null || true
    .venv/bin/python setup.py build_ext --inplace
    check_numpy
}

try_install_python310() {
    echo "Attempting installation with Python 3.10..."
    uv venv --python 3.10 --python-preference only-managed --clear
    source .venv/bin/activate
    uv pip install "setuptools<=59.8.0" "cython<0.30" pytest pytest-env hypothesis nose
    .venv/bin/python setup.py clean --all 2>/dev/null || true
    .venv/bin/python setup.py build_ext --inplace
    check_numpy
}

main() {
    echo "Starting NumPy installation attempts..."

    if try_install_python37; then
        echo "Successfully installed NumPy using Python 3.7"
        return 0
    fi

    echo "Python 3.7 installation failed, trying Python 3.8..."

    if try_install_python38; then
        echo "Successfully installed NumPy using Python 3.8"
        return 0
    fi

    echo "Python 3.8 installation failed, trying Python 3.9..."

    if try_install_python39; then
        echo "Successfully installed NumPy using Python 3.9"
        return 0
    fi

    echo "Python 3.9 installation failed, trying Python 3.10..."

    if try_install_python310; then
        echo "Successfully installed NumPy using Python 3.10"
        return 0
    fi

    echo "All installation attempts failed"
    return 1
}

# Run the main function
main
