# docker-compose handy functions
if ! command -v docker-compose &>/dev/null; then
	return 1
fi

[[ -z "$DKCP_DIR" ]] && export DKCP_DIR="/var/dkcmpo"


_get_dcp_file() {
	if [[ -z "$1" ]]; then
		echo "input para"
		return 1
	fi
	if [[ -z "$DKCP_DIR" ]]; then
		local DKCP_DIR=`pwd`
	fi
	local ext1=docker-compose.yml
	local ext2=docker-compose.yaml

	if [[ -e "$DKCP_DIR/$1/$ext1" ]]; then
		echo "$DKCP_DIR/$1/$ext1"
		return 0
	fi
	if [[ -e "$DKCP_DIR/$1/$ext2" ]]; then
		echo "$DKCP_DIR/$1/$ext2"
		return 0
	fi
	## try to grep
	local matched_file=`find $DKCP_DIR -maxdepth 3 -type f -name $ext1 -o -name $ext2 | xargs grep -El "[ ]+$1:$" | head -1`
	if [ $? -ne 0 ]; then
		echo "cannot find any y(a)ml files matched this service"
		return 1
	fi

	echo $matched_file
}

dcpupd() {
	svc_arr=("$@")
	svcs_len=${#svc_arr[*]}
	if [ $svcs_len -gt 0 ]; then
		for svc in ${svc_arr[*]}; do
			dcp_file=`_get_dcp_file $svc`
			if [ $? -eq 0 ]; then
				docker-compose -f $dcp_file up -d
			else
				echo "cannot determine service: $svc"
				continue
			fi
		done
	else # find all services restart: always/unless-stopped
		if [[ -z "$DKCP_DIR" ]]; then
			local DKCP_DIR=`pwd`
		fi
		local matched_arr=(`find $DKCP_DIR -maxdepth 3 -type f -name docker-compose.yml -o -name docker-compose.yaml | \
			xargs grep -El "[^#][ ]+restart:[ ]+always$|[^#][ ]+restart:[ ]+unless-stopped$"`)
		for dcp_file in ${matched_arr[*]}; do
			docker-compose -f $dcp_file up -d
		done
	fi
}

dcpdown() {
	svc_arr=("$@")
	svcs_len=${#svc_arr[*]}
	if [ $svcs_len -gt 0 ]; then
		for svc in ${svc_arr[*]}; do
			dcp_file=`_get_dcp_file $svc`
			if [ $? -eq 0 ]; then
				docker-compose -f $dcp_file down
			else
				echo "cannot determine service: $svc"
				continue
			fi
		done
	else # find all services restart: always/unless-stopped
		if [[ -z "$DKCP_DIR" ]]; then
			local DKCP_DIR=`pwd`
		fi
		local matched_arr=(`find $DKCP_DIR -maxdepth 3 -type f -name docker-compose.yml -o -name docker-compose.yaml`)
		for dcp_file in ${matched_arr[*]}; do
			docker-compose -f $dcp_file down
		done
	fi
}

