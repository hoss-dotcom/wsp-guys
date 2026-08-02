#!/usr/bin/env bash
#Modified by Entraptadoeztech and Crax!
set -euxo pipefail

# Cleanup function for error handling
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Script failed with exit code $exit_code"
        # Clean up temporary files
        if [ -n "${VER:-}" ]; then
            rm -rf "binaryen-${VER}" "binaryen-${VER}-x86_64-linux.tar.gz" 2>/dev/null || true
        fi
    fi
    exit $exit_code
}
trap cleanup EXIT

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$HOME/.local/share/pnpm:$PATH"

mkdir -p "$HOME/.local/bin" "$HOME/.local/lib" "$HOME/.local/share/pnpm"

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y #installs rustup
source "$HOME/.cargo/env"
hash -r 2>/dev/null || true

rustup toolchain install nightly --component rust-src --target wasm32-unknown-unknown

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
curl -fsSL https://get.pnpm.io/install.sh | sh - #installs pnpm
hash -r 2>/dev/null || true

pnpm install --frozen-lockfile

cargo install wasm-bindgen-cli --version 0.2.105 --locked

# Detect platform for binaryen
PLATFORM="x86_64-linux"
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $(uname -m) == "arm64" ]]; then
        PLATFORM="aarch64-macos"
    else
        PLATFORM="x86_64-macos"
    fi
elif [[ $(uname -m) == "aarch64" ]]; then
    PLATFORM="aarch64-linux"
fi

VER=$(curl --silent -qI https://github.com/WebAssembly/binaryen/releases/latest | awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}')
curl -LO "https://github.com/WebAssembly/binaryen/releases/download/$VER/binaryen-${VER}-${PLATFORM}.tar.gz"
tar xvf "binaryen-${VER}-${PLATFORM}.tar.gz"
rm -f "binaryen-${VER}-${PLATFORM}.tar.gz"
mv "binaryen-${VER}/bin"/* "$HOME/.local/bin/"
mv "binaryen-${VER}/lib"/* "$HOME/.local/lib/"
rm -rf "binaryen-${VER}"

cargo install --git https://github.com/r58playz/wasm-snip --locked

cd packages/core/ || exit 1
pnpm rewriter:build
pnpm build
cd ../../ || exit 1
