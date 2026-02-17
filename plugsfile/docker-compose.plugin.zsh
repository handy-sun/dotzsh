# docker-compose handy functions
if ! command -v docker-compose &>/dev/null; then
	return 1
fi

[[ -z "$DKCP_DIR" ]] && test -d "/var/dkcmpo" && export DKCP_DIR=/var/dkcmpo

dcpupd() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file up -d
}

dcpfru() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file up -d --force-recreate --remove-orphans
}

# dcplgf() {
#     local dcp_file=$DKCP_DIR/$1/docker-compose.yml
#     docker-compose -f $dcp_file logs -n 500 -f
# }

dcpdown() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file down --remove-orphans
}

dcpte() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file stop
}

dcprs() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file restart
}

dcppl() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file pull
}

dcppal() {
    for ctner in `ls $DKCP_DIR`; do
        local dcp_file=$DKCP_DIR/$ctner/docker-compose.yml
        if [ ! -e $dcp_file ]; then
            continue
        fi

        if ! grep -iq 'restart: no' $dcp_file; then
            docker-compose -f $dcp_file pull
        fi
    done
}

dcpca() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    if command -v bat &>/dev/null; then
        bat $dcp_file
    else
        cat $dcp_file
    fi
}
