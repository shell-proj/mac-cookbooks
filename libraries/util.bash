#!/bin/bash -e

###################
# ARRAY UTILITIES #
###################

function arrayToString()
{
    local -r array=("${@}")

    arrayToStringWithDelimiter ',' "${array[@]}"
}

function arrayToStringWithDelimiter()
{
    local -r delimiter="${1}"
    local -r array=("${@:2}")

    local -r string="$(printf "%s${delimiter}" "${array[@]}")"

    echo "${string:0:${#string} - ${#delimiter}}"
}

function isElementInArray()
{
    local -r element="${1}"

    local walker=''

    for walker in "${@:2}"
    do
        [[ "${walker}" = "${element}" ]] && echo 'true' && return 0
    done

    echo 'false' && return 1
}

########################
# FILE LOCAL UTILITIES #
########################

function appendToFileIfNotFound()
{
    local -r file="${1}"
    local -r pattern="${2}"
    local -r string="${3}"
    local -r patternAsRegex="${4}"
    local -r stringAsRegex="${5}"
    local -r addNewLine="${6}"

    # Validate Inputs

    checkExistFile "${file}"
    checkNonEmptyString "${pattern}" 'undefined pattern'
    checkNonEmptyString "${string}" 'undefined string'
    checkTrueFalseString "${patternAsRegex}"
    checkTrueFalseString "${stringAsRegex}"

    if [[ "${stringAsRegex}" = 'false' ]]
    then
        checkTrueFalseString "${addNewLine}"
    fi

    # Append String

    local grepOptions=('-F' '-o')

    if [[ "${patternAsRegex}" = 'true' ]]
    then
        grepOptions=('-E' '-o')
    fi

    local -r found="$(grep "${grepOptions[@]}" "${pattern}" "${file}")"

    if [[ "$(isEmptyString "${found}")" = 'true' ]]
    then
        if [[ "${stringAsRegex}" = 'true' ]]
        then
            echo -e "${string}" >> "${file}"
        else
            if [[ "${addNewLine}" = 'true' ]]
            then
                echo >> "${file}"
            fi

            echo "${string}" >> "${file}"
        fi
    fi
}

function checkValidJSONContent()
{
    local -r content="${1}"

    if [[ "$(isValidJSONContent "${content}")" = 'false' ]]
    then
        fatal '\nFATAL : invalid JSON'
    fi
}

function checkValidJSONFile()
{
    local -r file="${1}"

    if [[ "$(isValidJSONFile "${file}")" = 'false' ]]
    then
        fatal "\nFATAL : invalid JSON file '${file}'"
    fi
}

function copyFolderContent()
{
    local -r sourceFolder="${1}"
    local -r destinationFolder="${2}"

    checkExistFolder "${sourceFolder}"
    checkExistFolder "${destinationFolder}"

    local -r currentPath="$(pwd)"

    cd "${sourceFolder}"
    find '.' -maxdepth 1 -not -name '.' -exec cp -p -r '{}' "${destinationFolder}" \;
    cd "${currentPath}"
}

function createFileFromTemplate()
{
    local -r sourceFile="${1}"
    local -r destinationFile="${2}"
    local -r data=("${@:3}")

    checkExistFile "${sourceFile}"
    checkExistFolder "$(dirname "${destinationFile}")"

    local content
    content="$(cat "${sourceFile}")"

    local i=0

    for ((i = 0; i < ${#data[@]}; i = i + 2))
    do
        content="$(replaceString "${content}" "${data[${i}]}" "${data[${i} + 1]}")"
    done

    echo "${content}" > "${destinationFile}"
}

function createInitFileFromTemplate()
{
    local -r serviceName="${1}"
    local -r templateFolderPath="${2}"
    local -r initConfigData=("${@:3}")

    if [[ "$(isSystemdSupport)" = 'true' ]]
    then
        createFileFromTemplate "${templateFolderPath}/${serviceName}.service.systemd" "/etc/systemd/system/${serviceName}.service" "${initConfigData[@]}"
    else
        createFileFromTemplate "${templateFolderPath}/${serviceName}.conf.upstart" "/etc/init/${serviceName}.conf" "${initConfigData[@]}"
    fi
}

function getFileExtension()
{
    local -r string="${1}"

    local -r fullFileName="$(basename "${string}")"

    echo "${fullFileName##*.}"
}

function getFileName()
{
    local -r string="${1}"

    local -r fullFileName="$(basename "${string}")"

    echo "${fullFileName%.*}"
}

function isValidJSONContent()
{
    local -r content="${1}"

    if ( python -m 'json.tool' <<< "${content}" &> '/dev/null' )
    then
        echo 'true'
    else
        echo 'false'
    fi
}

function isValidJSONFile()
{
    local -r file="${1}"

    checkExistFile "${file}"

    isValidJSONContent "$(cat "${file}")"
}

function moveFolderContent()
{
    local -r sourceFolder="${1}"
    local -r destinationFolder="${2}"

    checkExistFolder "${sourceFolder}"
    checkExistFolder "${destinationFolder}"

    local -r currentPath="$(pwd)"

    cd "${sourceFolder}"
    find '.' -maxdepth 1 -not -name '.' -exec mv '{}' "${destinationFolder}" \;
    cd "${currentPath}"
}

function redirectOutputToLogFile()
{
    local -r logFile="${1}"

    mkdir -p "$(dirname "${logFile}")"
    exec > >(tee -a "${logFile}") 2>&1
}

function symlinkLocalBin()
{
    local -r sourceBinFolder="${1}"

    if [[ "$(isMacOperatingSystem)" = 'true' ]]
    then
        local -r type='-type'
    elif [[ "$(isCentOSDistributor)" = 'true' || "$(isRedHatDistributor)" = 'true' || "$(isUbuntuDistributor)" = 'true' ]]
    then
        local -r type='-xtype'
    else
        fatal '\nFATAL : only support CentOS, Mac, RedHat, Ubuntu OS'
    fi

    find "${sourceBinFolder}" -maxdepth 1 "${type}" f -perm -u+x -exec bash -c -e '
        for file
        do
            ln -f -s "${file}" "/usr/local/bin/$(basename "${file}")"
        done' bash '{}' \;
}

#########################
# FILE REMOTE UTILITIES #
#########################

function checkExistURL()
{
    local -r url="${1}"

    if [[ "$(existURL "${url}")" = 'false' ]]
    then
        fatal "\nFATAL : url '${url}' not found"
    fi
}

function downloadFile()
{
    local -r url="${1}"
    local -r destinationFile="${2}"
    local overwrite="${3}"

    checkExistURL "${url}"

    # Check Overwrite

    if [[ "$(isEmptyString "${overwrite}")" = 'true' ]]
    then
        overwrite='false'
    fi

    checkTrueFalseString "${overwrite}"

    # Validate

    if [[ -f "${destinationFile}" ]]
    then
        if [[ "${overwrite}" = 'false' ]]
        then
            fatal "\nFATAL : file '${destinationFile}' found"
        fi

        rm -f "${destinationFile}"
    elif [[ -e "${destinationFile}" ]]
    then
        fatal "\nFATAL : file '${destinationFile}' exists"
    fi

    # Download

    debug "\nDownloading '${url}' to '${destinationFile}'\n"
    curl -L "${url}" -o "${destinationFile}" --retry 12 --retry-delay 5
}

function existURL()
{
    local -r url="${1}"

    # Install Curl

    installCURLCommand > '/dev/null'

    # Check URL

    if ( curl -f --head -L "${url}" -o '/dev/null' -s --retry 12 --retry-delay 5 ||
         curl -f -L "${url}" -o '/dev/null' -r 0-0 -s --retry 12 --retry-delay 5 )
    then
        echo 'true'
    else
        echo 'false'
    fi
}

function getRemoteFileContent()
{
    local -r url="${1}"

    checkExistURL "${url}"
    curl -s -X 'GET' -L "${url}" --retry 12 --retry-delay 5
}

function unzipRemoteFile()
{
    local -r downloadURL="${1}"
    local -r installFolder="${2}"
    local extension="${3}"

    # Install Curl

    installCURLCommand

    # Validate URL

    checkExistURL "${downloadURL}"

    # Find Extension

    local exExtension=''

    if [[ "$(isEmptyString "${extension}")" = 'true' ]]
    then
        extension="$(getFileExtension "${downloadURL}")"
        exExtension="$(rev <<< "${downloadURL}" | cut -d '.' -f 1-2 | rev)"
    fi

    # Unzip

    if [[ "$(grep -i '^tgz$' <<< "${extension}")" != '' || "$(grep -i '^tar\.gz$' <<< "${extension}")" != '' || "$(grep -i '^tar\.gz$' <<< "${exExtension}")" != '' ]]
    then
        debug "\nDownloading '${downloadURL}'\n"
        curl -L "${downloadURL}" --retry 12 --retry-delay 5 | tar -C "${installFolder}" -x -z --strip 1
        echo
    elif [[ "$(grep -i '^zip$' <<< "${extension}")" != '' ]]
    then
        # Install Unzip

        installUnzipCommand

        # Unzip

        if [[ "$(existCommand 'unzip')" = 'false' ]]
        then
            fatal 'FATAL : command unzip not found'
        fi

        local -r zipFile="${installFolder}/$(basename "${downloadURL}")"

        downloadFile "${downloadURL}" "${zipFile}" 'true'
        unzip -q "${zipFile}" -d "${installFolder}"
        rm -f "${zipFile}"
        echo
    else
        fatal "\nFATAL : file extension '${extension}' not supported"
    fi
}

#####################
# PACKAGE UTILITIES #
#####################

function getLastAptGetUpdate()
{
    if [[ "$(isUbuntuDistributor)" = 'true' ]]
    then
        local -r aptDate="$(stat -c %Y '/var/cache/apt')"
        local -r nowDate="$(date +'%s')"

        echo $((nowDate - aptDate))
    fi
}

function installAptGetPackage()
{
    local -r package="${1}"

    if [[ "$(isUbuntuDistributor)" = 'true' ]]
    then
        if [[ "$(isAptGetPackageInstall "${package}")" = 'true' ]]
        then
            debug "\nApt-Get Package '${package}' has already been installed"
        else
            echo -e "\033[1;35m\nInstalling Apt-Get Package '${package}'\033[0m"
            DEBIAN_FRONTEND='noninteractive' apt-get install -y "${package}"
        fi
    fi
}

function installBuildEssential()
{
    if [[ "$(isUbuntuDistributor)" = 'true' ]]
    then
        installPackages 'build-essential'
    elif [[ "$(isCentOSDistributor)" = 'true' || "$(isRedHatDistributor)" = 'true' ]]
    then
        yum install -y gcc-c++ kernel-devel make
    else
        fatal '\nFATAL : only support CentOS, RedHat or Ubuntu OS'
    fi
}

function installPackages()
{
    local -r packages=("${@}")

    if [[ "$(isUbuntuDistributor)" = 'true' ]]
    then
        runAptGetUpdate ''
    fi

    local package=''

    for package in "${packages[@]}"
    do
        if [[ "$(isUbuntuDistributor)" = 'true' ]]
        then
            installAptGetPackage "${package}"
        elif [[ "$(isCentOSDistributor)" = 'true' || "$(isRedHatDistributor)" = 'true' ]]
        then
            yum install -y "${package}"
        else
            fatal '\nFATAL : only support CentOS, RedHat or Ubuntu OS'
        fi
    done
}

function installCleanUp()
{
    if [[ "$(isUbuntuDistributor)" = 'true' ]]
    then
        DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' clean
    fi
}

function installCommands()
{
    local -r data=("${@}")

    if [[ "$(isUbuntuDistributor)" = 'true' ]]
    then
        runAptGetUpdate ''
    fi

    local i=0

    for ((i = 0; i < ${#data[@]}; i = i + 2))
    do
        local command="${data[${i}]}"
        local package="${data[${i} + 1]}"

        checkNonEmptyString "${command}" 'undefined command'
        checkNonEmptyString "${package}" 'undefined package'

        if [[ "$(existCommand "${command}")" = 'false' ]]
        then
            installPackages "${package}"
        fi
    done
}

function installCURLCommand()
{
    local -r commandPackage=('curl' 'curl')

    installCommands "${commandPackage[@]}"
}

function installPackage()
{
    local -r aptPackage="${1}"
    local -r rpmPackage="${2}"

    if [[ "$(isUbuntuDistributor)" = 'true' ]]
    then
        installAptGetPackage "${aptPackage}"
    elif [[ "$(isCentOSDistributor)" = 'true' || "$(isRedHatDistributor)" = 'true' ]]
    then
        yum install -y "${rpmPackage}"
    else
        fatal '\nFATAL : only support CentOS, RedHat or Ubuntu OS'
    fi
}

function installPIPCommand()
{
    local -r commandPackage=('pip' 'python-pip')

    installCommands "${commandPackage[@]}"
}

function installPIPPackage()
{
    local -r package="${1}"

    if [[ "$(isPIPPackageInstall "${package}")" = 'true' ]]
    then
        debug "PIP Package '${package}' found"
    else
        echo -e "\033[1;35m\nInstalling PIP package '${package}'\033[0m"
        pip install "${package}"
    fi
}

function installUnzipCommand()
{
    local -r commandPackage=('unzip' 'unzip')

    installCommands "${commandPackage[@]}"
}

function isAptGetPackageInstall()
{
    local -r package="$(escapeGrepSearchPattern "${1}")"

    local -r found="$(dpkg --get-selections | grep -E -o "^${package}(:amd64)*\s+install$")"

    if [[ "$(isEmptyString "${found}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function isPIPPackageInstall()
{
    local -r package="$(escapeGrepSearchPattern "${1}")"

    # Install PIP

    installPIPCommand > '/dev/null'

    # Check Command

    if [[ "$(existCommand 'pip')" = 'false' ]]
    then
        fatal 'FATAL : command python-pip not found'
    fi

    local -r found="$(pip list | grep -E -o "^${package}\s+\(.*\)$")"

    if [[ "$(isEmptyString "${found}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function runAptGetUpdate()
{
    local updateInterval="${1}"

    if [[ "$(isUbuntuDistributor)" = 'true' ]]
    then
        local -r lastAptGetUpdate="$(getLastAptGetUpdate)"

        if [[ "$(isEmptyString "${updateInterval}")" = 'true' ]]
        then
            # Default To 24 hours
            updateInterval="$((24 * 60 * 60))"
        fi

        if [[ "${lastAptGetUpdate}" -gt "${updateInterval}" ]]
        then
            info 'apt-get update'
            apt-get update -m
        else
            local -r lastUpdate="$(date -u -d @"${lastAptGetUpdate}" +'%-Hh %-Mm %-Ss')"

            info "\nSkip apt-get update because its last run was '${lastUpdate}' ago"
        fi
    fi
}

function runAptGetUpgrade()
{
    if [[ "$(isUbuntuDistributor)" = 'true' ]]
    then
        runAptGetUpdate ''

        info '\napt-get upgrade'
        DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade

        info '\napt-get dist-upgrade'
        DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade

        info '\napt-get autoremove'
        DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' autoremove

        info '\napt-get clean'
        DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' clean

        info '\napt-get autoclean'
        DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' autoclean
    fi
}

function upgradePIPPackage()
{
    local -r package="${1}"

    if [[ "$(isPIPPackageInstall "${package}")" = 'true' ]]
    then
        echo -e "\033[1;35mUpgrading PIP package '${package}'\033[0m"
        pip install --upgrade "${package}"
    else
        debug "PIP Package '${package}' not found"
    fi
}

####################
# STRING UTILITIES #
####################

function checkNonEmptyString()
{
    local -r string="${1}"
    local -r errorMessage="${2}"

    if [[ "$(isEmptyString "${string}")" = 'true' ]]
    then
        if [[ "$(isEmptyString "${errorMessage}")" = 'true' ]]
        then
            fatal '\nFATAL : empty value detected'
        fi

        fatal "\nFATAL : ${errorMessage}"
    fi
}

function checkTrueFalseString()
{
    local -r string="${1}"

    if [[ "${string}" != 'true' && "${string}" != 'false' ]]
    then
        fatal "\nFATAL : '${string}' is not 'true' or 'false'"
    fi
}

function debug()
{
    local -r message="${1}"

    echo -e "\033[1;34m${message}\033[0m" 2>&1
}

function deleteSpaces()
{
    local -r content="${1}"

    replaceString "${content}" ' ' ''
}

function displayVersion()
{
    local -r message="${1}"

    header 'DISPLAYING VERSION'
    info "${message}"
}

function encodeURL()
{
    local -r url="${1}"

    local i=0
    local walker=''

    for ((i = 0; i < ${#url}; i++))
    do
        walker="${url:i:1}"

        case "${walker}" in
            [a-zA-Z0-9.~_-])
                printf '%s' "${walker}"
                ;;
            ' ')
                printf +
                ;;
            *)
                printf '%%%X' "'${walker}"
                ;;
        esac
    done
}

function error()
{
    local -r message="${1}"

    echo -e "\033[1;31m${message}\033[0m" 1>&2
}

function escapeGrepSearchPattern()
{
    local -r searchPattern="${1}"

    # shellcheck disable=SC2016
    sed 's/[]\.|$(){}?+*^]/\\&/g' <<< "${searchPattern}"
}

function escapeSearchPattern()
{
    local -r searchPattern="${1}"

    sed -e "s@\@@\\\\\\@@g" -e "s@\[@\\\\[@g" -e "s@\*@\\\\*@g" -e "s@\%@\\\\%@g" <<< "${searchPattern}"
}

function fatal()
{
    local -r message="${1}"

    error "${message}"
    exit 1
}

function formatPath()
{
    local path="${1}"

    while [[ "$(grep -F '//' <<< "${path}")" != '' ]]
    do
        path="$(sed -e 's/\/\/*/\//g' <<< "${path}")"
    done

    sed -e 's/\/$//g' <<< "${path}"
}

function header()
{
    local -r title="${1}"

    echo -e "\n\033[1;33m>>>>>>>>>> \033[1;4;35m${title}\033[0m \033[1;33m<<<<<<<<<<\033[0m\n"
}

function indentString()
{
    local -r indentString="$(escapeSearchPattern "${1}")"
    local -r string="$(escapeSearchPattern "${2}")"

    sed "s@^@${indentString}@g" <<< "${string}"
}

function info()
{
    local -r message="${1}"

    echo -e "\033[1;36m${message}\033[0m" 2>&1
}

function invertTrueFalseString()
{
    local -r string="${1}"

    checkTrueFalseString "${string}"

    if [[ "${string}" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function isEmptyString()
{
    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true'
    else
        echo 'false'
    fi
}

function removeEmptyLines()
{
    local -r content="${1}"

    echo -e "${content}" | sed '/^\s*$/d'
}

function replaceString()
{
    local -r content="${1}"
    local -r oldValue="$(escapeSearchPattern "${2}")"
    local -r newValue="$(escapeSearchPattern "${3}")"

    sed "s@${oldValue}@${newValue}@g" <<< "${content}"
}

function stringToSearchPattern()
{
    local -r string="$(trimString "${1}")"

    if [[ "$(isEmptyString "${string}")" = 'true' ]]
    then
        echo "${string}"
    else
        echo "^\s*$(sed -e 's/\s\+/\\s+/g' <<< "$(escapeSearchPattern "${string}")")\s*$"
    fi
}

function trimString()
{
    local -r string="${1}"

    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

function warn()
{
    local -r message="${1}"

    echo -e "\033[1;33m${message}\033[0m" 1>&2
}

####################
# SYSTEM UTILITIES #
####################

function addUser()
{
    local -r userLogin="${1}"
    local -r groupName="${2}"
    local -r createHome="${3}"
    local -r systemAccount="${4}"
    local -r allowLogin="${5}"

    checkNonEmptyString "${userLogin}" 'undefined user login'
    checkNonEmptyString "${groupName}" 'undefined group name'

    # Options

    if [[ "${createHome}" = 'true' ]]
    then
        local -r createHomeOption=('-m')
    else
        local -r createHomeOption=('-M')
    fi

    if [[ "${allowLogin}" = 'true' ]]
    then
        local -r allowLoginOption=('-s' '/bin/bash')
    else
        local -r allowLoginOption=('-s' '/bin/false')
    fi

    # Add Group

    groupadd -f -r "${groupName}"

    # Add User

    if [[ "$(existUserLogin "${userLogin}")" = 'true' ]]
    then
        if [[ "$(isUserLoginInGroupName "${userLogin}" "${groupName}")" = 'false' ]]
        then
            usermod -a -G "${groupName}" "${userLogin}"
        fi

        # Not Exist Home

        if [[ "${createHome}" = 'true' ]]
        then
            local -r userHome="$(getUserHomeFolder "${userLogin}")"

            if [[ "$(isEmptyString "${userHome}")" = 'true' || ! -d "${userHome}" ]]
            then
                mkdir -p "/home/${userLogin}"
                chown -R "${userLogin}:${groupName}" "/home/${userLogin}"
            fi
        fi
    else
        if [[ "${systemAccount}" = 'true' ]]
        then
            useradd "${createHomeOption[@]}" -r "${allowLoginOption[@]}" -g "${groupName}" "${userLogin}"
        else
            useradd "${createHomeOption[@]}" "${allowLoginOption[@]}" -g "${groupName}" "${userLogin}"
        fi
    fi
}

function addUserAuthorizedKey()
{
    local -r userLogin="${1}"
    local -r groupName="${2}"
    local -r sshRSA="${3}"

    configUserSSH "${userLogin}" "${groupName}" "${sshRSA}" 'authorized_keys'
}

function addUserSSHKnownHost()
{
    local -r userLogin="${1}"
    local -r groupName="${2}"
    local -r sshRSA="${3}"

    configUserSSH "${userLogin}" "${groupName}" "${sshRSA}" 'known_hosts'
}

function addUserToSudoWithoutPassword()
{
    local -r userLogin="${1}"

    echo "${userLogin} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${userLogin}"
    chmod 440 "/etc/sudoers.d/${userLogin}"
}

function checkExistCommand()
{
    local -r command="${1}"
    local -r errorMessage="${2}"

    if [[ "$(existCommand "${command}")" = 'false' ]]
    then
        if [[ "$(isEmptyString "${errorMessage}")" = 'true' ]]
        then
            fatal "\nFATAL : command '${command}' not found"
        fi

        fatal "\nFATAL : ${errorMessage}"
    fi
}

function checkExistFile()
{
    local -r file="${1}"
    local -r errorMessage="${2}"

    if [[ "${file}" = '' || ! -f "${file}" ]]
    then
        if [[ "$(isEmptyString "${errorMessage}")" = 'true' ]]
        then
            fatal "\nFATAL : file '${file}' not found"
        fi

        fatal "\nFATAL : ${errorMessage}"
    fi
}

function checkExistFolder()
{
    local -r folder="${1}"
    local -r errorMessage="${2}"

    if [[ "${folder}" = '' || ! -d "${folder}" ]]
    then
        if [[ "$(isEmptyString "${errorMessage}")" = 'true' ]]
        then
            fatal "\nFATAL : folder '${folder}' not found"
        fi

        fatal "\nFATAL : ${errorMessage}"
    fi
}

function checkExistGroupName()
{
    local -r groupName="${1}"

    if [[ "$(existGroupName "${groupName}")" = 'false' ]]
    then
        fatal "\nFATAL : group name '${groupName}' not found"
    fi
}

function checkExistUserLogin()
{
    local -r userLogin="${1}"

    if [[ "$(existUserLogin "${userLogin}")" = 'false' ]]
    then
        fatal "\nFATAL : user login '${userLogin}' not found"
    fi
}

function checkRequirePorts()
{
    local -r ports=("${@}")

    installPackage 'lsof' 'lsof'

    local -r headerRegex='^COMMAND\s\+PID\s\+USER\s\+FD\s\+TYPE\s\+DEVICE\s\+SIZE\/OFF\s\+NODE\s\+NAME$'
    local -r status="$(lsof -i -n -P | grep "\( (LISTEN)$\)\|\(${headerRegex}\)")"
    local open=''
    local port=''

    for port in "${ports[@]}"
    do
        # shellcheck disable=SC2155
        local found="$(grep -i ":${port} (LISTEN)$" <<< "${status}")"

        if [[ "$(isEmptyString "${found}")" = 'false' ]]
        then
            open="${open}\n${found}"
        fi
    done

    if [[ "$(isEmptyString "${open}")" = 'false' ]]
    then
        echo -e    "\033[1;31mFollowing ports are still opened. Make sure you uninstall or stop them before a new installation!\033[0m"
        echo -e -n "\033[1;34m\n$(grep "${headerRegex}" <<< "${status}")\033[0m"
        echo -e    "\033[1;36m${open}\033[0m\n"

        exit 1
    fi
}

function checkRequireRootUser()
{
    checkRequireUserLogin 'root'
}

function checkRequireLinuxSystem()
{
    if [[ "$(isCentOSDistributor)" = 'false' && "$(isRedHatDistributor)" = 'false' && "$(isUbuntuDistributor)" = 'false' ]]
    then
        fatal '\nFATAL : only support CentOS, RedHat or Ubuntu OS'
    fi

    if [[ "$(is64BitSystem)" = 'false' ]]
    then
        fatal '\nFATAL : non x86_64 OS found'
    fi
}

function checkRequireMacSystem()
{
    if [[ "$(isMacOperatingSystem)" = 'false' ]]
    then
        fatal '\nFATAL : only support Mac OS'
    fi

    if [[ "$(is64BitSystem)" = 'false' ]]
    then
        fatal '\nFATAL : non x86_64 OS found'
    fi
}

function checkRequireUserLogin()
{
    local -r userLogin="${1}"

    if [[ "$(whoami)" != "${userLogin}" ]]
    then
        fatal "\nFATAL : user login '${userLogin}' required"
    fi
}

function cleanUpSystemFolders()
{
    header 'CLEANING UP SYSTEM FOLDERS'

    local -r folders=(
        '/tmp'
        '/var/tmp'
    )

    local folder=''

    for folder in "${folders[@]}"
    do
        echo "Cleaning up folder '${folder}'"
        emptyFolder "${folder}"
    done
}

function configUserGIT()
{
    local -r userLogin="${1}"
    local -r gitUserName="${2}"
    local -r gitUserEmail="${3}"

    header "CONFIGURING GIT FOR USER ${userLogin}"

    checkExistUserLogin "${userLogin}"
    checkNonEmptyString "${gitUserName}" 'undefined git user name'
    checkNonEmptyString "${gitUserEmail}" 'undefined git user email'

    su -l "${userLogin}" -c "git config --global user.name '${gitUserName}'"
    su -l "${userLogin}" -c "git config --global user.email '${gitUserEmail}'"
    su -l "${userLogin}" -c 'git config --global push.default simple'

    info "$(su -l "${userLogin}" -c 'git config --list')"
}

function configUserSSH()
{
    local -r userLogin="${1}"
    local -r groupName="${2}"
    local -r sshRSA="${3}"
    local -r configFileName="${4}"

    header "CONFIGURING ${configFileName} FOR USER ${userLogin}"

    checkExistUserLogin "${userLogin}"
    checkExistGroupName "${groupName}"
    checkNonEmptyString "${sshRSA}" 'undefined SSH-RSA'
    checkNonEmptyString "${configFileName}" 'undefined config file'

    local -r userHome="$(getUserHomeFolder "${userLogin}")"

    checkExistFolder "${userHome}"

    mkdir -p "${userHome}/.ssh"
    chmod 700 "${userHome}/.ssh"

    touch "${userHome}/.ssh/${configFileName}"
    appendToFileIfNotFound "${userHome}/.ssh/${configFileName}" "${sshRSA}" "${sshRSA}" 'false' 'false' 'false'
    chmod 600 "${userHome}/.ssh/${configFileName}"

    chown -R "${userLogin}:${groupName}" "${userHome}/.ssh"

    cat "${userHome}/.ssh/${configFileName}"
}

function deleteUser()
{
    local -r userLogin="${1}"

    if [[ "$(existUserLogin "${userLogin}")" = 'true' ]]
    then
        userdel -f -r "${userLogin}" 2> '/dev/null' || true
    fi
}

function displayOpenPorts()
{
    local -r sleepTimeInSecond="${1}"

    installPackage 'lsof' 'lsof'

    header 'DISPLAYING OPEN PORTS'

    if [[ "$(isEmptyString "${sleepTimeInSecond}")" = 'false' ]]
    then
        sleep "${sleepTimeInSecond}"
    fi

    lsof -i -n -P | grep -i ' (LISTEN)$' | sort -f
}

function emptyFolder()
{
    local -r folder="${1}"

    checkExistFolder "${folder}"

    local -r currentPath="$(pwd)"

    cd "${folder}"
    find '.' -not -name '.' -delete
    cd "${currentPath}"
}

function existCommand()
{
    local -r command="${1}"

    if [[ "$(which "${command}" 2> '/dev/null')" = '' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function existDisk()
{
    local -r disk="${1}"

    local -r foundDisk="$(fdisk -l "${disk}" 2> '/dev/null' | grep -E -i -o "^Disk\s+$(escapeGrepSearchPattern "${disk}"): ")"

    if [[ "$(isEmptyString "${disk}")" = 'false' && "$(isEmptyString "${foundDisk}")" = 'false' ]]
    then
        echo 'true'
    else
        echo 'false'
    fi
}

function existDiskMount()
{
    local -r disk="$(escapeGrepSearchPattern "${1}")"
    local -r mountOn="$(escapeGrepSearchPattern "${2}")"

    local -r foundMount="$(df | grep -E "^${disk}\s+.*\s+${mountOn}$")"

    if [[ "$(isEmptyString "${foundMount}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function existGroupName()
{
    local -r group="${1}"

    if [[ "$(grep -E -o "^${group}:" '/etc/group')" = '' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function existModule()
{
    local -r module="${1}"

    checkNonEmptyString "${module}" 'undefined module'

    if [[ "$(lsmod | awk '{ print $1 }' | grep -F -o "${module}")" = '' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function existMount()
{
    local -r mountOn="$(escapeGrepSearchPattern "${1}")"

    local -r foundMount="$(df | grep -E ".*\s+${mountOn}$")"

    if [[ "$(isEmptyString "${foundMount}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function existUserLogin()
{
    local -r user="${1}"

    if ( id -u "${user}" > '/dev/null' 2>&1 )
    then
        echo 'true'
    else
        echo 'false'
    fi
}

function generateUserSSHKey()
{
    local -r userLogin="${1}"
    local groupName="${2}"

    # Set Default

    if [[ "$(isEmptyString "${groupName}")" = 'true' ]]
    then
        groupName="${userLogin}"
    fi

    # Validate Input

    checkExistUserLogin "${userLogin}"
    checkExistGroupName "${groupName}"

    local -r userHome="$(getUserHomeFolder "${userLogin}")"

    checkExistFolder "${userHome}"

    # Generate SSH Key

    header "GENERATING SSH KEY FOR USER '${userLogin}'"

    rm -f "${userHome}/.ssh/id_rsa" "${userHome}/.ssh/id_rsa.pub"
    ssh-keygen -q -t rsa -N '' -f "${userHome}/.ssh/id_rsa"
    chmod 600 "${userHome}/.ssh/id_rsa" "${userHome}/.ssh/id_rsa.pub"
    chown "${userLogin}:${groupName}" "${userHome}/.ssh/id_rsa" "${userHome}/.ssh/id_rsa.pub"

    cat "${userHome}/.ssh/id_rsa.pub"
}

function getCurrentUserHomeFolder()
{
    getUserHomeFolder "$(whoami)"
}

function getMachineDescription()
{
    lsb_release -d -s
}

function getMachineRelease()
{
    lsb_release -r -s
}

function getProfileFilePath()
{
    local -r user="${1}"

    local -r userHome="$(getUserHomeFolder "${user}")"

    if [[ "$(isEmptyString "${userHome}")" = 'false' && -d "${userHome}" ]]
    then
        local -r bashProfileFilePath="${userHome}/.bash_profile"
        local -r profileFilePath="${userHome}/.profile"
        local defaultStartUpFilePath="${bashProfileFilePath}"

        if [[ ! -f "${bashProfileFilePath}" && -f "${profileFilePath}" ]]
        then
            defaultStartUpFilePath="${profileFilePath}"
        fi

        echo "${defaultStartUpFilePath}"
    else
        echo
    fi
}

function getTemporaryFile()
{
    local extension="${1}"

    if [[ "$(isEmptyString "${extension}")" = 'false' && "$(grep -i -o "^." <<< "${extension}")" != '.' ]]
    then
        extension=".${extension}"
    fi

    mktemp "$(getTemporaryFolderRoot)/$(date +'%Y%m%d-%H%M%S')-XXXXXXXXXX${extension}"
}

function getTemporaryFolder()
{
    mktemp -d "$(getTemporaryFolderRoot)/$(date +'%Y%m%d-%H%M%S')-XXXXXXXXXX"
}

function getTemporaryFolderRoot()
{
    local temporaryFolder='/tmp'

    if [[ "$(isEmptyString "${TMPDIR}")" = 'false' ]]
    then
        temporaryFolder="$(formatPath "${TMPDIR}")"
    fi

    echo "${temporaryFolder}"
}

function getUserGroupName()
{
    local -r userLogin="${1}"

    checkExistUserLogin "${userLogin}"

    id -g -n "${userLogin}"
}

function getUserHomeFolder()
{
    local -r user="${1}"

    if [[ "$(isEmptyString "${user}")" = 'false' ]]
    then
        local -r homeFolder="$(eval "echo ~${user}")"

        if [[ "${homeFolder}" = "\~${user}" ]]
        then
            echo
        else
            echo "${homeFolder}"
        fi
    else
        echo
    fi
}

function initializeFolder()
{
    local -r folder="${1}"

    if [[ -d "${folder}" ]]
    then
        emptyFolder "${folder}"
    else
        mkdir -p "${folder}"
    fi
}

function is64BitSystem()
{
    isMachineHardware 'x86_64'
}

function isCentOSDistributor()
{
    isDistributor 'centos'
}

function isDistributor()
{
    local -r distributor="${1}"

    local -r found="$(grep -F -i -o -s "${distributor}" '/proc/version')"

    if [[ "$(isEmptyString "${found}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function isLinuxOperatingSystem()
{
    isOperatingSystem 'Linux'
}

function isMachineHardware()
{
    local -r machineHardware="$(escapeGrepSearchPattern "${1}")"

    local -r found="$(uname -m | grep -E -i -o "^${machineHardware}$")"

    if [[ "$(isEmptyString "${found}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function isMacOperatingSystem()
{
    isOperatingSystem 'Darwin'
}

function isOperatingSystem()
{
    local -r operatingSystem="$(escapeGrepSearchPattern "${1}")"

    local -r found="$(uname -s | grep -E -i -o "^${operatingSystem}$")"

    if [[ "$(isEmptyString "${found}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function isPortOpen()
{
    local -r port="$(escapeGrepSearchPattern "${1}")"

    checkNonEmptyString "${port}" 'undefined port'

    if [[ "$(isLinuxOperatingSystem)" = 'true' ]]
    then
        local -r process="$(netstat -l -n -t -u | grep -E ":${port}\s+" | head -1)"
    elif [[ "$(isMacOperatingSystem)" = 'true' ]]
    then
        local -r process="$(lsof -i -n -P | grep -E -i ":${port}\s+\(LISTEN\)$" | head -1)"
    else
        fatal '\nFATAL : operating system not supported'
    fi

    if [[ "$(isEmptyString "${process}")" = 'true' ]]
    then
        echo 'false'
    else
        echo 'true'
    fi
}

function isRedHatDistributor()
{
    isDistributor 'RedHat'
}

function isSystemdSupport()
{
    if [[ "$(existCommand 'systemctl')" = 'true' ]]
    then
        echo 'true'
    else
        echo 'false'
    fi
}

function isUbuntuDistributor()
{
    isDistributor 'Ubuntu'
}

function isUserLoginInGroupName()
{
    local -r userLogin="${1}"
    local -r groupName="${2}"

    checkNonEmptyString "${userLogin}" 'undefined user login'
    checkNonEmptyString "${groupName}" 'undefined group name'

    if [[ "$(existUserLogin "${userLogin}")" = 'true' ]]
    then
        if [[ "$(groups "${userLogin}" | grep "\b${groupName}\b")" = '' ]]
        then
            echo 'false'
        else
            echo 'true'
        fi
    else
        echo 'false'
    fi
}

function remountTMP()
{
    header 'RE-MOUNTING TMP'

    if [[ "$(existMount '/tmp')" = 'true' ]]
    then
        mount -o 'remount,rw,exec,nosuid' -v '/tmp'
    else
        warn 'WARN : mount /tmp not found'
    fi
}

function resetLogs()
{
    header 'RESETTING LOGS'

    find '/var/log' -type f \( -regex '.*\.[0-9]+' -o -regex '.*\.[0-9]+\.gz' -o -regex '.*\.old' \) -delete -print
    find '/var/log' -type f -exec cp -f '/dev/null' '{}' \; -print
}

function restartService()
{
    local -r serviceName="${1}"

    checkNonEmptyString "${serviceName}" 'undefined service name'

    stopService "${serviceName}"
    startService "${serviceName}"
}

function startService()
{
    local -r serviceName="${1}"

    checkNonEmptyString "${serviceName}" 'undefined service name'

    if [[ "$(isSystemdSupport)" = 'true' ]]
    then
        header "STARTING SYSTEMD SERVICE ${serviceName}"

        systemctl daemon-reload
        systemctl start "${serviceName}"
        systemctl status "${serviceName}" --full --no-pager
        systemctl enable "${serviceName}"
    else
        header "STARTING UPSTART SERVICE ${serviceName}"

        start "${serviceName}"
    fi
}

function stopService()
{
    local -r serviceName="${1}"

    checkNonEmptyString "${serviceName}" 'undefined service name'

    if [[ "$(isSystemdSupport)" = 'true' ]]
    then
        header "STOPPING SYSTEMD SERVICE ${serviceName}"

        systemctl daemon-reload
        systemctl stop "${serviceName}"
    else
        header "STOPPING UPSTART SERVICE ${serviceName}"

        stop "${serviceName}"
    fi
}