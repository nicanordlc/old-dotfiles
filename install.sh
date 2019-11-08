#!/bin/bash -e
# shellcheck disable=1090,1117

#################
#               #
# Trapped files #
#               #
#################
TEMP_PASSWORD=$(mktemp)
CSV=$(mktemp)
trap '{ rm -rf $CSV ; }' SIGINT SIGTERM EXIT

# Consant
# =======
IS_ZSH=$(
    if [ "$(basename "$SHELL")" == "zsh" ]; then
        echo "true"
    fi
)

# Source script to source (¯\_(ツ)_/¯)
# ===================================
. ~/.scripts/sourceifexists

# Source BEGINS
# ======================
sourceIfExists ./config/{install,managers,utils}/*.sh

#####################
#                   #
# Prepare log files #
#                   #
#####################
BASE_PATH=~/.dots
LOG_DST="${BASE_PATH}/install.log"
LOG_DST_STATUS="${BASE_PATH}/install-status.log"
mkdir -p $BASE_PATH
touch $LOG_DST
touch $LOG_DST_STATUS

__install() {
    local APPS_CSV MAPPER MAPPER_TYPE TYPE NAME STATE DESCRIPTION
    APPS_CSV=$1

    # Strip comments and empty lines
    sed -e '/^#/d' -e '/^$/d' "$APPS_CSV" >"$CSV"

    IFS=,
    while read -rs TYPE NAME STATE DESCRIPTION; do
        MAPPER_TYPE=$TYPE

        # Format `type` for loggin purposes
        [[ "$TYPE" ]] &&
            TYPE="- $TYPE -"

        # If the app is installed or turned off do nothing
        __is_installed $LOG_DST_STATUS "$NAME" "$TYPE" ||
            [[ "$STATE" == "off" ]] &&
            continue

        case $MAPPER_TYPE in
        a) MAPPER=__aur ;;
        f) MAPPER=__function ;;
        m) MAPPER=__make_pkg ;;
        "") MAPPER=__package_manager ;;
        gem) MAPPER=__gem ;;
        pip) MAPPER=__pip ;;
        node) MAPPER=__node ;;
        esac

        [[ "$DESCRIPTION" ]] &&
            DESCRIPTION="\n\t$DESCRIPTION"

        # Mapper's header (Log)
        echo -e "🏃 $NAME $TYPE $DESCRIPTION" | tee -a $LOG_DST

        # Execute
        $MAPPER "$NAME" | tee -a $LOG_DST 2>&1

        # Status (Log)
        echo -e "$TYPE :: $NAME :: $?\n" >>$LOG_DST_STATUS
    done <"$CSV"
}

__prompt_password() {
    local PROMPT_PASSWORD

    if [ "$PASSWORD" ]; then
        echo "$PASSWORD" >"$TEMP_PASSWORD"
    else
        read -rsp "Type sudo password for later use 😉🔒:" PROMPT_PASSWORD
        echo
        echo "$PROMPT_PASSWORD" >"$TEMP_PASSWORD"
    fi
}

__set_shell_zsh() {
    # set zsh as default shell
    if [ "$IS_ZSH" ] || ! command -v zsh; then
        return 0
    fi

    chsh -s "$(grep /zsh$ /etc/shells | tail -1)" <"$TEMP_PASSWORD"
}

#########
#       #
# Begin #
#       #
#########

main() {
    echo "[Installing]..."

    local OS CSV_SUFFIX DEFAULT_APPS_FILES APPS_FILES APPS_FILE

    # mac related stuffs
    case "$(uname -s)" in
    [Dd]arwin)
        export OS="mac"
        export CSV_SUFFIX="-mac"
        ;;
    *) echo "" ;;
    esac

    DEFAULT_APPS_FILES=(
        "./config/common.csv"
        "./config/apps${CSV_SUFFIX}.csv"
    )

    APPS_FILES=("${@:-${DEFAULT_APPS_FILES[*]}}")

    # __prompt_password

    for APPS_FILE in ${APPS_FILES[*]}; do
        if ! [ -f "$APPS_FILE" ]; then
            echo "$APPS_FILE -- This file does not exists"
            continue
        fi

        __install "$APPS_FILE"
    done

    __set_shell_zsh
}

main "$@"
