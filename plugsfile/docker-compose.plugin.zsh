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

dcplgf() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file logs -n 500 -f
}

dcpdown() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file down --remove-orphans
}

dcpte() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file stop
}

dcppl() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file pull
}
