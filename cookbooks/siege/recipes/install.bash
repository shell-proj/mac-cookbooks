#!/bin/bash -e

function install()
{
    # Clean Up

    initializeFolder "${SIEGE_INSTALL_FOLDER}"
    initializeFolder "${SIEGE_INSTALL_FOLDER}/bin"

    # Install

    local -r tempFolder="$(getTemporaryFolder)"

    unzipRemoteFile "${SIEGE_DOWNLOAD_URL}" "${tempFolder}"
    cd "${tempFolder}"
    "${tempFolder}/configure" --prefix="${SIEGE_INSTALL_FOLDER}"
    make
    make install
    chown -R "${SUDO_USER}:$(getUserGroupName "${SUDO_USER}")" "${SIEGE_INSTALL_FOLDER}"
    cd
    rm -f -r "${tempFolder}"
    ln -f -s "${SIEGE_INSTALL_FOLDER}/bin/siege" '/usr/local/bin/siege'

    # Display Version

    displayVersion "$("${SIEGE_INSTALL_FOLDER}/bin/siege" --version 2>&1)"
}

function main()
{
    local -r appFolderPath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    source "${appFolderPath}/../../../libraries/util.bash"
    source "${appFolderPath}/../attributes/default.bash"

    checkRequireMacSystem
    checkRequireRootUser

    header 'INSTALLING SIEGE'

    install
}

main "${@}"