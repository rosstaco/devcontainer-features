# Plan: prompty-dumpty DevContainer Feature

Install prompty-dumpty (v0.6.2 current) Python package system-wide using pip3 with `--break-system-packages` flag. The CLI command `dumpty` will be available globally after installation.

## Steps

1. **Create feature structure** at `src/prompty-dumpty/` with `devcontainer-feature.json` (id: "prompty-dumpty", version option only with default "latest", no `installsAfter` or installPath), `README.md` documenting the `dumpty` command, and `.gitignore`

2. **Write install script** at `src/prompty-dumpty/install.sh` with `set -e` for fail-fast behavior, detect package manager (apt/apk/yum), install `python3-pip` if missing, run `pip3 install prompty-dumpty --break-system-packages` (latest) or `pip3 install prompty-dumpty==VERSION --break-system-packages` (specific version like 0.6.2)

3. **Add verification and output** using `command -v dumpty` to verify installation, run `dumpty --version`, display colored success message with installation details following `src/microsoft-security-devops-cli/install.sh` colored output pattern

4. **Create test suite** at `test/prompty-dumpty/` with `test.sh` (installs latest, verifies `dumpty` exists), `version.sh` (installs version 0.6.2 specifically), and `scenarios.json` testing both scenarios on debian/ubuntu base images

## Further Considerations

None - ready to implement with fail-fast on errors and pip's default install paths.
