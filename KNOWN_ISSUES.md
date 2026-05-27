# Known Issues — ARM64 Gold Evaluation

> **Maintainers**: Update this file whenever new failure patterns are discovered during gold evaluation runs.

---

## Status Summary (as of 2026-03-06)

| # | Project | Instances Affected | Root Cause | Status | Fix Location |
|---|---------|-------------------|------------|--------|--------------|
| 1 | Pillow | 3 | Missing `Tests/helper.py` in `r2e_tests/` | **Fixed** | `build_arm64_dockers.py` |
| 2 | Scrapy | 3 (cssselect) | `cssselect>=1.2` removed `_unicode_safe_getattr` private API | **Fixed** | `scrapy_install.sh` |
| 3 | Orange3 | 3 | AnyQt installed without a Qt backend (PyQt5) | **Fixed** | `orange3_install.sh`, `Dockerfile.orange3` |
| 4 | DataLad | 2 (wrapt) | Missing `wrapt` transitive dependency | **Fixed** | `datalad_install.sh` |
| 5 | diff_classes.py | 3 | Corrupt gold patches (new-file headers, `None` in hunk ranges) | **Fixed** | `diff_classes.py` |
| 6 | DataLad | 1 | Missing `conftest.py` with pytest fixtures | **Fixed** | `build_arm64_dockers.py` |
| 7 | DataLad | 1 | Missing `mock` package | **Fixed** | `datalad_install.sh`, `Dockerfile.datalad` |
| 8 | DataLad | 1 | Missing `appdirs` package | **Fixed** | `datalad_install.sh`, `Dockerfile.datalad` |
| 9 | DataLad | 1 | Missing `pkg_resources` (needs `setuptools`) + pytest 8.x `yield` incompatibility | **Fixed** | `datalad_install.sh`, `Dockerfile.datalad` |
| 10 | Scrapy | 1 | Missing `Twisted` at conftest load time | **Fixed** | `scrapy_install.sh`, `Dockerfile.scrapy` |
| 11 | aiohttp | 2 | Gold patch fails `git apply` (`patch_successfully_applied: false`) | **Open** | `diff_classes.py` |
| 12 | Pyramid | 2 | Module path mismatch (`r2e_tests.test_1` vs `pyramid.tests.test_viewderivers`) | **Won't fix** | Inherent test-relocation limitation |
| 13 | Pyramid | 1 | Missing fixture files (`r2e_tests/fixtures/manifest.json`) | **Open** | `build_arm64_dockers.py` |
| 14 | Pyramid | 1 | All tests pass but `resolved: false` (eval test-name mismatch) | **Open** | Eval harness / test-name mapping |
| 15 | pandas | ~33 | `-Werror` in `setup.py` + ARM64 ujson `fastcall` attribute warning | **Fixed** | `pandas_install.sh` |
| 16 | pandas | ~97 | `uv venv --clear` silently fails → Python 3.8 persists for later attempts | **Fixed** | `pandas_install.sh` |

---

## Detailed Descriptions

### 1. Pillow — missing `helper.py` (FIXED)

**Instances**: 3 Pillow instances
**Error**: `ModuleNotFoundError: No module named 'helper'`
**Cause**: Pillow tests import from `Tests/helper.py`, but this file wasn't included in the HF dataset's test data. The original pipeline in `repo_testextract.py` extracts it, but it wasn't recorded.
**Fix**: `build_arm64_dockers.py` now extracts `Tests/helper.py` from the repo checkout at `old_commit_hash` and copies it into `r2e_tests/`.

---

### 2. Scrapy — cssselect incompatibility (FIXED)

**Instances**: 3 Scrapy instances
**Error**: `AttributeError: module 'cssselect' has no attribute '_unicode_safe_getattr'`
**Cause**: `cssselect>=1.2` removed the `_unicode_safe_getattr` private API that old Scrapy versions import.
**Fix**: `scrapy_install.sh` pins `cssselect<1.2`.

---

### 3. Orange3 — missing Qt backend on ARM64 (FIXED)

**Instances**: 3 Orange3 instances
**Error**: `ImportError: PyQt4, PyQt5, PySide or PySide2 are not available for import`
**Cause**: AnyQt is a compatibility shim that needs a real Qt backend. The original ARM64 code just skipped PyQt installation. First fix installed AnyQt alone (insufficient). PyQt5 has no pre-built ARM64 pip wheels, so pip install hangs trying to compile from source.
**Fix**:
- `Dockerfile.orange3`: Added `qtbase5-dev qt5-qmake libqt5svg5-dev libqt5websockets5-dev` to the early apt-get layer so PyQt5 can build from source with pre-installed headers.
- `orange3_install.sh`: `install_pyqt()` now installs Qt5 dev headers via apt, then `uv pip install PyQt5 AnyQt`.
- **Important**: System `python3-pyqt5` (apt) is compiled for system Python 3.10 and CANNOT be symlinked into Python 3.8/3.9 venvs due to ABI mismatch. Must build from source via pip against the correct venv Python.

---

### 4. DataLad — missing `wrapt` (FIXED)

**Instances**: 2 DataLad instances
**Error**: `ModuleNotFoundError: No module named 'wrapt'`
**Cause**: DataLad imports `wrapt` transitively but it wasn't explicitly installed.
**Fix**: `datalad_install.sh` adds `wrapt` to both Python 3.9 and 3.7 pip install lines.

---

### 5. Corrupt gold patches — `diff_classes.py` (FIXED)

**Instances**: 3 instances across repos
**Error**: `git apply` fails on the gold patch
**Cause**: `FileDiff.get_patch()` had two bugs:
1. New files: Used `header.file.path` (could be `/dev/null`) instead of `plus_file.path` for `diff --git` header.
2. Range `None`: `length=None` was string-interpolated as `"None"` in hunk headers like `@@ -0,0 +1,None @@`.
**Fix**: `diff_classes.py` — use `plus_file` path for new files; inline range formatting to handle `None`.

---

### 6. DataLad — missing `conftest.py` (FIXED)

**Instances**: 1 DataLad instance
**Error**: Pytest fixtures (`path`, `setup_git_config`) not found
**Cause**: DataLad tests require a `conftest.py` with specific fixtures, but it wasn't included in the test data.
**Fix**: `build_arm64_dockers.py` injects `datalads_conftest.py` into `r2e_tests/conftest.py` when not already present.

---

### 7. DataLad — missing `mock` (FIXED)

**Instances**: `datalad__datalad-022cfde`
**Error**: `ModuleNotFoundError: No module named 'mock'`
**Cause**: Test does `from mock import patch`. In Python 3.x the stdlib has `unittest.mock`, but the standalone `mock` package isn't installed.
**Fix**: `datalad_install.sh` adds `mock` to pip install. `Dockerfile.datalad` adds a late-stage `RUN uv pip install mock appdirs setuptools && uv pip install "pytest<8"`.

---

### 8. DataLad — missing `appdirs` (FIXED)

**Instances**: `datalad__datalad-1736edc`
**Error**: `ModuleNotFoundError: No module named 'appdirs'`
**Cause**: `datalad/interface/common_cfg.py` does `from appdirs import AppDirs` but `appdirs` isn't in the dependency install.
**Fix**: `datalad_install.sh` adds `appdirs` to pip install.

---

### 9. DataLad — missing `pkg_resources` + pytest 8.x yield error (FIXED)

**Instances**: `datalad__datalad-22948af`
**Errors**:
1. `'yield' keyword is allowed in fixtures, but not in tests (test_setup_store)` — pytest 8.x rejects `yield` in test functions.
2. `ModuleNotFoundError: No module named 'pkg_resources'` — `datalad/api.py` does `from pkg_resources import iter_entry_points`.
**Fix**: `datalad_install.sh` pins `"pytest<8"` and adds `setuptools` (provides `pkg_resources`).

---

### 10. Scrapy — missing `Twisted` (FIXED)

**Instances**: `scrapy__scrapy-d91183`
**Error**: `ModuleNotFoundError: No module named 'twisted'` when loading `/testbed/conftest.py`
**Cause**: The project's root `conftest.py` does `from twisted.web.http import H2_ENABLED`. `uv pip install -e .` should install Twisted as a Scrapy dependency, but didn't for this commit. Other Scrapy instances pass because their conftest doesn't import Twisted.
**Fix**: `scrapy_install.sh` explicitly adds `Twisted`. `Dockerfile.scrapy` adds a late-stage `RUN uv pip install Twisted`.

---

### 11. aiohttp — gold patch fails to apply (OPEN)

**Instances**: `aio-libs__aiohttp-8999d9b`, `aio-libs__aiohttp-9726a67`
**Error**: `patch_successfully_applied: false`. No test output generated.
**Cause**: The gold patches generated by `diff_classes.py` are still malformed for these specific commits. The previous fix (#5) addressed new-file headers and `None` ranges, but these two instances hit a different code path that still produces invalid patches.
**Next step**: Dump the generated patches for these instances and run `git apply --check` to identify the exact rejection reason. May involve renamed files, binary diffs, or edge cases in the patch format.

---

### 12. Pyramid — module path mismatch (WON'T FIX)

**Instances**: `Pylons__pyramid-6c16fb0`, `Pylons__pyramid-7410250` (partially — 6 of 94 and 3 of 45 tests fail)
**Error**: Tests assert on `pyramid.tests.test_viewderivers.view` but get `r2e_tests.test_1.view`
**Cause**: Pyramid's runtime generates error messages containing `view.__module__`. When tests run from `r2e_tests/test_1.py`, the module becomes `r2e_tests.test_1` instead of the original path. Test assertions compare these strings exactly.
**Why not fixable**: Fixing this requires knowing the original file paths (not preserved in the HF dataset) to set `__module__` on relocated test classes.

---

### 13. Pyramid — missing fixture files (OPEN)

**Instances**: `Pylons__pyramid-7410250` (3 of 45 tests fail)
**Error**: `FileNotFoundError: [Errno 2] No such file or directory: '/testbed/r2e_tests/fixtures/manifest.json'`
**Cause**: Tests reference `os.path.join(here, 'fixtures', 'manifest.json')` where `here` resolves to `r2e_tests/`. The fixture files from `pyramid/tests/fixtures/` aren't copied into `r2e_tests/`.
**Fix needed**: `build_arm64_dockers.py` should copy `pyramid/tests/fixtures/` into `r2e_tests/fixtures/` at build time (similar to the Pillow `helper.py` fix).

---

### 14. Pyramid — all tests pass but `resolved: false` (OPEN)

**Instances**: `Pylons__pyramid-11cbc8f`
**Error**: All 21 tests PASS, but evaluation marks it as `resolved: false`.
**Cause**: The evaluation framework checks FAIL_TO_PASS / PASS_TO_PASS test expectations in `expected_output_json`. The expected test names use original module paths (e.g., `pyramid.tests.test_pcreate.TestPCreateCommand::test_it`) which don't match the relocated names (`r2e_tests.test_1.TestPCreateCommand::test_it`). Even though all tests pass, the eval can't match expected test names to actual output.
**Fix needed**: Either remap test names in the eval harness, or accept this as a known limitation of test relocation.

---

### 15. pandas — `-Werror` + ARM64 ujson `fastcall` attribute (FIXED)

**Instances**: ~100 pandas instances in `build_push_state.m1.json`
**Error**: `pandas/_libs/src/ujson/lib/ultrajsondec.c:71:39: error: 'fastcall' attribute directive ignored [-Werror=attributes]` → `ModuleNotFoundError: No module named 'pandas._libs.json'`
**Cause**: Many pandas versions add `-Werror` to the `extra_compile_args` for their vendored ujson C extension in `setup.py`. On ARM64, GCC warns that the x86-only `fastcall` calling convention attribute is ignored. With `-Werror`, this warning becomes a fatal compilation error. The `pandas._libs.json` shared library fails to build, and the pandas import subsequently fails.
The install script already sets `CFLAGS="-Wno-error ..."`, but this is ineffective because pandas' `setup.py` appends `-Werror` *after* CFLAGS in the compiler command line, and GCC processes flags left-to-right (last one wins).
All four build attempts fail:
1. Python 3.7: not available on ARM64
2. Python 3.8 (Cython<0.30): ujson `-Werror` kills the json extension
3. Python 3.9 (Cython 0.29.36): same ujson issue
4. Python 3.10 (Cython 3.0.5): Cython 3 incompatibility (`reduction.pyx` read-only property errors)

**Fix**: `pandas_install.sh` now runs `sed -i 's/-Werror/-Wno-error/g' setup.py` on ARM64 before building. This neutralises the flag while preserving Python list syntax. Also made `requirements-dev.txt` install conditional (some pandas versions don't have it).

---

### 16. pandas — `uv venv --clear` silent failure (FIXED)

**Instances**: ~97 pandas instances (64 `TypeError: 'type' object is not subscriptable` + 15 `functools.cache` + 18 Cython 3 that would now succeed with earlier attempts)
**Errors**:
1. `TypeError: 'type' object is not subscriptable` at `PrePostDevType = Union[InfiniteTypes, tuple[str, int]]`
2. `AttributeError: module 'functools' has no attribute 'cache'`

**Cause**: `uv venv --python "3.9" --clear` silently fails when switching Python versions:
```
error: Failed to create virtual environment
  Caused by: A virtual environment already exists at `.venv`. Use `--clear` to replace it
```
Despite `--clear` being passed, the old `.venv` (Python 3.8 from attempt #2) persists. Attempts #3 (Python 3.9) and #4 (Python 3.10) end up installing packages into the old Python 3.8 venv. Newer pandas versions that use PEP 585 syntax (`tuple[str, int]`) or `functools.cache` (both Python 3.9+) fail at import time.
Since `build_and_check_pandas` is called from `if`, bash's `set -e` is disabled inside it — so the venv creation failure doesn't stop execution.
**Fix**: `pandas_install.sh` now uses `rm -rf .venv && uv venv --python "${python_ver}"` instead of `uv venv --python "${python_ver}" --clear`.

---

## General Notes

- **Install scripts vs Dockerfiles**: Install scripts (`*_install.sh`) run during `docker build` and are baked into images. Editing them does NOT affect existing images — images must be rebuilt.
- **Dockerfile late-stage layers**: Adding `RUN` commands after `ENV VIRTUAL_ENV=...` in Dockerfiles allows fast cache-friendly rebuilds since Docker caches all earlier layers.
- **ARM64 PyQt5**: There are no pre-built ARM64 pip wheels for PyQt5. Must either build from source (needs Qt5 dev headers) or use system packages (only works if venv Python version matches system Python).
- **Rebuild command**: `python3 src/r2egym/repo_analysis/build_arm64_dockers.py --instance-file <file> --rebuild --repos <repo1,repo2> --push --registry <registry>`
