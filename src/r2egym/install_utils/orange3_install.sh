#!/bin/bash

set -e  # Exit on any error

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  export CFLAGS="-O0 -Wno-error -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types"
  echo "[INFO] Detected ARM64 ($ARCH) -- using relaxed CFLAGS: $CFLAGS"
fi

IS_ARM=false
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  IS_ARM=true
fi

check_orange() {
    echo "Verifying Orange installation..."
    if .venv/bin/python -c "import Orange; print(Orange.__file__)"   &> /dev/null; then
        echo "✅ Orange installation successful!"
        ln -sf Orange/tests/datasets/ datasets
        return 0
    else
        echo "❌ Orange verification failed"
        return 1
    fi
}

install_pyqt() {
    if $IS_ARM; then
        echo "[INFO] ARM64: installing Qt5 dev headers + building PyQt5 from source"
        apt-get update -qq && apt-get install -y -qq qtbase5-dev qt5-qmake libqt5svg5-dev libqt5websockets5-dev 2>/dev/null || true
        uv pip install PyQt5 AnyQt || uv pip install "PyQt5-sip>=12.8" "PyQt5>=5.15" AnyQt || uv pip install AnyQt || true
    else
        uv pip install "PyQt5>=5.12,!=5.15.1" "PyQtWebEngine>=5.12"
    fi
}

try_install_python37() {
    echo "Attempting installation with Python 3.7..."
    uv venv --python 3.7 --python-preference only-managed --clear
    source .venv/bin/activate
    uv pip install --upgrade "setuptools<60" "numpy<1.22" wheel "cython<0.30" pytest
    install_pyqt
    uv pip install -r requirements-core.txt
    uv pip install -r requirements-gui.txt
    uv pip install -r requirements-sql.txt
    if [ -f requirements-opt.txt ]; then
        uv pip install -r requirements-opt.txt
    fi
    uv pip install scipy scikit-learn
    .venv/bin/python setup.py build_ext --inplace
    .venv/bin/python setup.py develop
    check_orange
}

try_install_python38() {
    echo "Attempting installation with Python 3.8..."
    uv venv --python 3.8 --python-preference only-managed --clear
    source .venv/bin/activate
    uv pip install --upgrade "setuptools>=62,<66" "numpy<1.25" wheel "cython<0.30" pytest
    install_pyqt
    uv pip install -r requirements-core.txt
    uv pip install -r requirements-gui.txt
    uv pip install -r requirements-sql.txt
    if [ -f requirements-opt.txt ]; then
        uv pip install -r requirements-opt.txt
    fi
    .venv/bin/python setup.py build_ext --inplace
    .venv/bin/python setup.py develop
    check_orange
}

try_install_python39() {
    echo "Attempting installation with Python 3.9..."
    uv venv --python 3.9 --python-preference only-managed --clear
    source .venv/bin/activate
    uv pip install --upgrade "setuptools>=62,<66" "numpy<1.25" wheel "cython<0.30" pytest
    install_pyqt
    uv pip install -r requirements-core.txt
    uv pip install -r requirements-gui.txt
    uv pip install -r requirements-sql.txt
    if [ -f requirements-opt.txt ]; then
        uv pip install -r requirements-opt.txt
    fi
    .venv/bin/python setup.py build_ext --inplace
    .venv/bin/python setup.py develop
    check_orange
}

try_install_python310() {
    echo "Attempting installation with Python 3.10..."
    uv venv --python 3.10 --python-preference only-managed --clear
    source .venv/bin/activate
    uv pip install --upgrade "setuptools>=62,<66" numpy wheel cython pytest
    install_pyqt
    uv pip install -r requirements-core.txt
    uv pip install -r requirements-gui.txt
    if [ -f requirements-dev.txt ]; then
        uv pip install -r requirements-dev.txt
    fi
    uv pip install -r requirements-sql.txt
    .venv/bin/python setup.py build_ext --inplace
    .venv/bin/python setup.py develop
    uv pip install -e . --no-build-isolation --no-binary=orange3
    check_orange
}

main() {
    echo "Starting Orange installation attempts..."

    if try_install_python37; then
        echo "Successfully installed orange using Python 3.7"
        return 0
    fi

    echo "Python 3.7 installation failed, trying Python 3.8..."

    if try_install_python38; then
        echo "Successfully installed orange using Python 3.8"
        return 0
    fi

    echo "Python 3.8 installation failed, trying Python 3.9..."

    if try_install_python39; then
        echo "Successfully installed orange using Python 3.9"
        return 0
    fi

    echo "Python 3.9 installation failed, trying Python 3.10..."

    if try_install_python310; then
        echo "Successfully installed orange using Python 3.10"
        return 0
    fi

    echo "All installation attempts failed"
    return 1
}

# Run the main function
main
