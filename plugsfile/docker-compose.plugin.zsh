# docker-compose handy functions
if ! command -v docker-compose &>/dev/null; then
	return 1
fi

[[ -z "$DKCP_DIR" ]] && test -d "/var/dkcmpo" && export DKCP_DIR=/var/dkcmpo

dcpupd() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file up -d
}

dcpfrupd() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file up -d --force-recreate --remove-orphans
}

dcplgf() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file logs -f
}

dcpte() {
    local dcp_file=$DKCP_DIR/$1/docker-compose.yml
    docker-compose -f $dcp_file stop
}
