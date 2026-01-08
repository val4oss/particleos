#!/bin/bash

MKOSI_BIN="/home/valentin/workspace/src/github.com/val4oss/mkosi/bin/"
if ! command mkosi &> /dev/null
then
    export PATH=$PATH:$MKOSI_BIN
    export MKOSI_INTERPRETER="/usr/bin/python3.13"
fi
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
TARGET_IMG="$SCRIPT_DIR/mkosi.output/target-disk.img"
LOCAL_CONF="$SCRIPT_DIR/mkosi.local.conf"

# Function to clean up mkosi artifacts
# Returns nothing
function _clean() {
    mkosi -f clean && rm -rf mkosi.output mkosi.cache
    [ -e ~/.cache/mkosi ] && rm -rf ~/.cache/mkosi
}

# Function to run the build process
# Returns 0 on success, non-zero on failure
function _build() {
    log_f="./output.log"
    rm "$log_f"
    touch "$log_f"
    mkosi genkey
    mkosi --debug -B -ff -d opensuse -r tumbleweed 2>&1 | tee "$log_f"
    return $?
}

# Function to create a QEMU target from the built image
# Run the mkosi vm command after setting up the target disk image
function _create_target() {
    if [ ! -f "$TARGET_IMG" ]; then
        qemu-img create -f raw "$TARGET_IMG" 30G
    fi
    # IF not present add with sed the Qemu=ARg in the local config
    if ! grep -q "^QemuArgs=" "$LOCAL_CONF"; then
        {
            echo "QemuArgs="
            echo "  -drive if=none,file=${TARGET_IMG},format=raw,id=installdisk"
            echo "  -device virtio-blk-pci,drive=installdisk"
        } >> "$LOCAL_CONF"
    fi
    mkosi vm
}

# Function to boot the QEMU target
function _boot_target() {
    # If QemuArgs is present in the local config, remove it with following lines
    if grep -q "^QemuArgs=" "$LOCAL_CONF"; then
        sed -i '/^QemuArgs=/,/^$/d' "$LOCAL_CONF"
    fi
    # Get the current link to the particleOS Image
    current_image_link=$(
        find "$SCRIPT_DIR/mkosi.output/" \
            -maxdepth 1 \
            -type l \
            -name "ParticleOS_*_x86-64" | head -n 1
        )
    if [ -z "$current_image_link" ]; then
        echo "No ParticleOS image link found in mkosi.output/"
        return 1
    fi
    ln -sf "${TARGET_IMG}" "${current_image_link}"
    mkosi vm
}

function _summary() {
    mkosi summary
}

case "$1" in
    "build")
        _build
        exit $?
        ;;
    "clean")
        _clean
        exit 0
        ;;
    "create-target")
        _create_target
        exit $?
        ;;
    "boot-target")
        _boot_target
        exit $?
        ;;
    "summary")
        _summary
        exit $?
        ;;
    *)
        echo "Usage: $0 {build|clean|create-target|boot-target|summary}"
        exit 1
        ;;
esac


