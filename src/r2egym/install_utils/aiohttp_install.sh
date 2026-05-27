ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  export CFLAGS="-O0 -Wno-error -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types"
  echo "[INFO] Detected ARM64 ($ARCH) -- using relaxed CFLAGS: $CFLAGS"
fi

uv venv --python 3.9
source .venv/bin/activate

make .develop

uv pip install pytest pytest-asyncio pytest-cov pytest-asyncio pytest-mock coverage gunicorn async-generator brotlipy cython multdict yarl async-timeout trustme chardet

.venv/bin/python process_aiohttp_updateasyncio.py