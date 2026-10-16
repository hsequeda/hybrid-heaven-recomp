#!/usr/bin/env bash
# One-time preparation for a Linux build: distribution packages, the splat
# virtual environment and the submodules. From Pilotwings 64: Recompiled's script.
#
# What each package is for:
#
#   clang, lld            the port (N64Recomp's output is validated against Clang;
#                         GCC is never used, docs/PLAN.md).
#   cmake, ninja-build, pkg-config   the build.
#   python3, python3-venv the pipeline's tools and splat.
#   binutils-mips-linux-gnu  assembling and linking the ELF from splat's output.
#   libsdl2-dev           the window, the pad and the audio device.
#   libfreetype-dev       RmlUi's font engine, under recompui.
#   libgtk-3-dev          nativefiledialog-extended, the dump picker.
#   libvulkan-dev         RT64's renderer on Linux.
#   mesa-vulkan-drivers   a driver to run it (skip with a proprietary stack).
#   vulkan-tools          vulkaninfo, for when the renderer will not start.
#
# Nothing is installed without asking: with no arguments the script prints what
# is missing and the command that installs it. Pass --install to run it.
#
#   bash tools/setup_linux.sh [--install]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PACKAGES=(
    clang lld cmake ninja-build pkg-config git
    python3 python3-venv binutils-mips-linux-gnu
    libsdl2-dev libfreetype-dev libgtk-3-dev
    libvulkan-dev vulkan-tools mesa-vulkan-drivers
)

install=0
[ "${1:-}" = "--install" ] && install=1

# ------------------------------------------------------------- packages ----
if command -v pacman > /dev/null; then
    # Arch includes development headers and Python's venv module in the main
    # packages. SDL2 is provided by sdl2-compat in the official repositories.
    ARCH_PACKAGES=(
        base-devel clang lld cmake ninja pkgconf git python
        sdl2-compat freetype2 gtk3 vulkan-headers vulkan-icd-loader vulkan-tools
    )
    missing=()
    for p in "${ARCH_PACKAGES[@]}"; do
        if ! pacman -Q "$p" > /dev/null 2>&1; then
            missing+=("$p")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        echo "packages: all present"
    elif [ "$install" -eq 1 ]; then
        echo "installing: ${missing[*]}"
        # Refresh and upgrade together: Arch does not support partial upgrades.
        sudo pacman -Syu --needed "${missing[@]}"
    else
        echo "missing packages: ${missing[*]}"
        echo "Install them with:"
        echo "    sudo pacman -Syu --needed ${missing[*]}"
        echo
    fi

    # Cross-binutils is separate from Arch's native binutils package.
    if ! command -v mips-linux-gnu-as > /dev/null ||
       ! command -v mips-linux-gnu-ld > /dev/null; then
        aur_helper=""
        for helper in yay paru; do
            if command -v "$helper" > /dev/null; then
                aur_helper="$helper"
                break
            fi
        done
        if [ "$install" -eq 1 ] && [ -n "$aur_helper" ]; then
            "$aur_helper" -S --needed mips-linux-gnu-binutils
        else
            echo "Missing MIPS cross-binutils (AUR: mips-linux-gnu-binutils)."
            echo "Install with: yay -S --needed mips-linux-gnu-binutils"
            echo "or build https://aur.archlinux.org/packages/mips-linux-gnu-binutils with makepkg -si."
            echo "Then re-run this script."
            exit 1
        fi
        if ! command -v mips-linux-gnu-as > /dev/null ||
           ! command -v mips-linux-gnu-ld > /dev/null; then
            echo "MIPS cross-binutils installation did not provide the required assembler and linker." >&2
            exit 1
        fi
    fi
    echo "Vulkan runtime: install the driver for your GPU (e.g. vulkan-radeon, vulkan-intel, or nvidia-utils)."
    if [ ${#missing[@]} -ne 0 ] && [ "$install" -eq 0 ]; then
        echo "Re-run with --install after reviewing the package list."
        exit 1
    fi
elif command -v dpkg-query > /dev/null; then
    missing=()
    for p in "${PACKAGES[@]}"; do
        if dpkg-query -W -f='${Status}' "$p" 2> /dev/null | grep -q "install ok installed"; then
            continue
        fi
        # A versioned toolchain counts: Debian and Ubuntu install clang-21 and
        # friends without the unversioned metapackage.
        if [ "$p" = clang ] && ls /usr/bin/clang++-[0-9]* > /dev/null 2>&1; then
            continue
        fi
        if [ "$p" = lld ] && ls /usr/bin/ld.lld-[0-9]* /usr/lib/llvm-*/bin/ld.lld > /dev/null 2>&1; then
            continue
        fi
        missing+=("$p")
    done

    if [ ${#missing[@]} -eq 0 ]; then
        echo "packages: all present"
    elif [ "$install" -eq 1 ]; then
        echo "installing: ${missing[*]}"
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}"
    else
        echo "missing packages: ${missing[*]}"
        echo
        echo "Install them with:"
        echo "    sudo apt-get install ${missing[*]}"
        echo "or re-run this script as: bash tools/setup_linux.sh --install"
        echo
    fi
else
    echo "Unsupported package manager -- install the equivalents of these yourself:"
    printf '    %s\n' "${PACKAGES[@]}"
    echo
fi

# ----------------------------------------------------------------- splat ----
echo "=== splat (virtual environment) ==="
bash "$REPO/tools/wsl_setup_splat.sh"

# ------------------------------------------------------------ submodules ----
echo "=== submodules ==="
git -C "$REPO" submodule update --init --recursive

echo
echo "Ready. Next:"
echo "    bash tools/build_linux.sh '/path/to/Hybrid Heaven (USA).z64'"
