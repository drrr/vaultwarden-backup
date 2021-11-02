#!/bin/bash

set -ex

# Use the value of the corresponding environment variable, or the
# default if none exists.
: ${TARGET_ROOT:="$(realpath "${0%/*}"/..)"}
: ${RCLONE:="/usr/local/bin/rclone"}
: ${GPG:="/usr/bin/gpg"}
: ${AGE:="/usr/local/bin/age"}

# Change DATA_DIR
DATA_DIR="data"
BACKUP_ROOT="${TARGET_ROOT}/backup"
BACKUP_DIR_NAME="backup-$(date '+%Y%m%d-%H%M')"
BACKUP_DIR_PATH="${BACKUP_ROOT}/${BACKUP_DIR_NAME}"
BACKUP_FILE_DIR="archives"
BACKUP_FILE_NAME="${BACKUP_DIR_NAME}.tar.xz"
BACKUP_FILE_PATH="${BACKUP_ROOT}/${BACKUP_FILE_DIR}/${BACKUP_FILE_NAME}"

source "${BACKUP_ROOT}"/backup.conf

cd "${TARGET_ROOT}"
mkdir -p "${BACKUP_DIR_PATH}"

tar -cJf "${BACKUP_FILE_PATH}" -C "${BACKUP_ROOT}" "${BACKUP_DIR_NAME}"
rm -rf "${BACKUP_DIR_PATH}"
md5sum "${BACKUP_FILE_PATH}"
sha1sum "${BACKUP_FILE_PATH}"

if [[ -n ${GPG_PASSPHRASE} ]]; then
    # https://gnupg.org/documentation/manuals/gnupg/GPG-Esoteric-Options.html
    # Note: Add `--pinentry-mode loopback` if using GnuPG 2.1.
    printf '%s' "${GPG_PASSPHRASE}" |
    ${GPG} -c --cipher-algo "${GPG_CIPHER_ALGO}" --batch --passphrase-fd 0 "${BACKUP_FILE_PATH}"
    BACKUP_FILE_NAME+=".gpg"
    BACKUP_FILE_PATH+=".gpg"
    md5sum "${BACKUP_FILE_PATH}"
    sha1sum "${BACKUP_FILE_PATH}"
elif [[ -n ${AGE_PASSPHRASE} ]]; then
    export AGE_PASSPHRASE
    ${AGE} -p -o "${BACKUP_FILE_PATH}.age" "${BACKUP_FILE_PATH}"
    BACKUP_FILE_NAME+=".age"
    BACKUP_FILE_PATH+=".age"
    md5sum "${BACKUP_FILE_PATH}"
    sha1sum "${BACKUP_FILE_PATH}"
fi

# Attempt uploading to all remotes, even if some fail.
set +e

for dest in "${RCLONE_DESTS[@]}"; do
    ${RCLONE} -vv --no-check-dest copy "${BACKUP_FILE_PATH}" "${dest}"
done
