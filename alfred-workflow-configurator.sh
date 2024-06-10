#!/bin/zsh --no-rcs

# requires jq
command -v jq &>/dev/null || { echo "jq is required: try \`brew install jq\`"; exit 1; }

wfdir_unresolved=$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder)
if [[ ! -n $wfdir_unresolved ]] ; then
	wfdir=$(jq -r '"\(.current)/workflows"' "$HOME/Library/Application Support/Alfred/prefs.json")
else
	wfdir=$(eval echo "$wfdir_unresolved/Alfred.alfredpreferences/workflows")
fi
[[ -d $wfdir ]] || { echo "workflow dir could not be determined"; exit 1; }
CFG_DIR=$(realpath "$wfdir/../..")
CONFIG_FILE="$CFG_DIR/alfredworkflows.ini"

typeset -gA WORKFLOWS
typeset -gA WF_ARRAY

_usage() {
	cat <<-EOF
	usage: ${1:t} [opts]
	    --table   print name, current state, and bundleid of every workflow on your system
	    --check   check and set workflow states to match saved config
	    --init    generate configuration file from current state
	    --cfg     open config: $CONFIG_FILE
	    --github  open GitHub repo page in browser
	EOF
}

_red() { printf '\e[1;31m%s\e[0m\n' "$1"; }
_green() { printf '\e[1;32m%s\e[0m\n' "$1"; }

_getkey() {
	plutil -extract "$1" raw -- "$2"
}

_bool() {
	case $1 in
		disabled) echo "true";;
		enabled) echo "false";;
		*) echo "false";; # ???
	esac
}

_read_config() {
	[[ -e $CONFIG_FILE ]] || { echo "configuration does not exist, run with \`--init\`"; exit 1; }
	while IFS='=' read -r key value; do
		WORKFLOWS[$key]=$value
	done <"$CONFIG_FILE"
}

_populate() {
	while read -r PLIST ; do
		STATUS_KEY=$(_getkey disabled "$PLIST")
		case $STATUS_KEY in
			true) STATUS='disabled';;
			*) STATUS='enabled';;
		esac
		BUNDLE_ID=$(_getkey bundleid "$PLIST")
		NAME=$(_getkey name "$PLIST")
		WF_ARRAY[$BUNDLE_ID]="$NAME"$'\t'"$STATUS"$'\t'"$PLIST"
		if [[ $1 != '--skipcheck' ]] && [[ -z ${WORKFLOWS[$BUNDLE_ID]} ]] ; then
			_red "undeclared workflow: $NAME [$BUNDLE_ID]"
		fi
	done < <(find "$wfdir" -maxdepth 2 -type f -iname info.plist)
}

_table() {
	_populate --skipcheck
	for BUNDLE_ID in "${(@k)WF_ARRAY[@]}" ; do
		IFS=$'\t' read -r NAME STATUS PLIST <<< "${WF_ARRAY[$BUNDLE_ID]}"
		printf '%s\t%s\t%s\n' "$NAME" "$STATUS" "$BUNDLE_ID"
	done | sort -f |
	column -s$'\t' -t
}

_check() {
	_read_config
	_populate
	c=0
	for BUNDLE_ID in "${(@k)WF_ARRAY[@]}" ; do
		IFS=$'\t' read -r NAME STATUS PLIST <<< "${WF_ARRAY[$BUNDLE_ID]}"
		WANT_STATUS=${WORKFLOWS[$BUNDLE_ID]}
		[[ -n $WANT_STATUS ]] || continue #undeclared workflow
		if [[ $STATUS != "$WANT_STATUS" ]] ; then
			(( c++ ))
			echo "changing $NAME [$BUNDLE_ID] to $WANT_STATUS"
			plutil -replace disabled -bool "$(_bool "$WANT_STATUS")" "$PLIST"
		fi
	done
	(( c == 0 )) && echo -n "all workflows configured correctly " ; _green '✔'
}

_init() {
	_populate --skipcheck
	for BUNDLE_ID in "${(@k)WF_ARRAY[@]}" ; do
		IFS=$'\t' read -r _ STATUS _ <<< "${WF_ARRAY[$BUNDLE_ID]}"
		echo "${BUNDLE_ID}=${STATUS}"
	done |
	sort -f > "$CONFIG_FILE"
}

case $1 in
	-h|--help|'') _usage "$0";;
	--table) _table;;
	--check) _check;;
	--init) _init; open "$CONFIG_FILE";;
	--cfg) _read_config; open "$CONFIG_FILE";;
	--github) open "https://github.com/luckman212/alfred-workflow-configurator";;
esac
