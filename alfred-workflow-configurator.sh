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
PREFS_CFG_FILE="$CFG_DIR/alfredprefs.ini"
ALFRED_PREFS_DOMAIN='com.runningwithcrayons.Alfred-Preferences'

typeset -gA WORKFLOWS
typeset -gA WF_ARRAY
typeset -aA PREFS_SAVED
typeset -gA PREFS_KEYS=(
	[selectedWorkflowCategory]='string'
	[workflowpalette.hidden]='boolean'
	[workflows.hideGalleryBadges]='boolean'
	[workflows.hideGalleryUpdates]='boolean'
	[workflows.onlyShowDisabled]='boolean'
	[workflows.onlyShowEnabled]='boolean'
	[workflows.showCategories]='boolean'
	[workflows.showCreator]='boolean'
	[workflows.showHotkeys]='boolean'
	[workflows.showLastModified]='boolean'
	[workflows.sortMode]='integer'
)

_usage() {
	cat <<-EOF
	usage: ${1:t} [command]
	    --table          print name, current state, and bundleid of every workflow on your system
	    --check          check and set workflow states to match saved config
	    --init           generate configuration file from current state
	    --prefs [save]   configure Alfred Preferences.app settings according to defined values
	    --cfg            open directory where config files are stored
	    --github         open GitHub repo page in browser
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
	done < "$CONFIG_FILE"
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
	(( c == 0 )) && { echo -n "all workflows configured correctly " ; _green '✔'; }
}

_init() {
	_populate --skipcheck
	for BUNDLE_ID in "${(@k)WF_ARRAY[@]}" ; do
		IFS=$'\t' read -r _ STATUS _ <<< "${WF_ARRAY[$BUNDLE_ID]}"
		echo "${BUNDLE_ID}=${STATUS}"
	done |
	sort -f > "$CONFIG_FILE"
}

_boolOrNot() {
	case $1 in
		bool*) # convert to true/false
			case $2 in
				1) echo "true"; return;;
				0) echo "false"; return;;
				*) echo >&2 "unexpected arg passed to function"; exit 1;;
			esac
			;;
		*) echo "$2";; #pass thru as-is
	esac
}

_prefs() {
	case $1 in
		save|--save)
			for PREFS_KEY in "${(@k)PREFS_KEYS[@]}" ; do
				value=$(defaults read "$ALFRED_PREFS_DOMAIN" "$PREFS_KEY" 2>/dev/null)
				echo "${PREFS_KEY}=${value}"
			done |
			sort -f > "$PREFS_CFG_FILE"
			echo "saved prefs config based on current settings"
			exit
			;;
	esac
	[[ -e $PREFS_CFG_FILE ]] || { echo "prefs configuration does not exist, run with \`--prefs save\`"; exit 1; }
	while IFS='=' read -r key value; do
		[[ -n $key ]] && PREFS_SAVED[$key]=$value
	done < "$PREFS_CFG_FILE"
	c=0
	for PREFS_KEY in "${(@k)PREFS_KEYS[@]}" ; do
		want_val=${PREFS_SAVED[$PREFS_KEY]}
		keytype=${PREFS_KEYS[$PREFS_KEY]}
		cur_value=$(defaults read "$ALFRED_PREFS_DOMAIN" "$PREFS_KEY" 2>/dev/null)
		if [[ $cur_value != $want_val ]]; then
			(( c++ ))
			if [[ -n $want_val ]]; then
				defaults write "$ALFRED_PREFS_DOMAIN" "$PREFS_KEY" -$keytype $(_boolOrNot "$keytype" "$want_val")
				echo "changed: $PREFS_KEY=$want_val ($keytype)"
			else
				defaults delete "$ALFRED_PREFS_DOMAIN" "$PREFS_KEY"
				echo "removed: $PREFS_KEY"
			fi
		fi
	done < "$PREFS_CFG_FILE"
	(( c == 0 )) && { echo -n "all prefs configured correctly " ; _green '✔'; }
}

case $1 in
	-h|--help|'') _usage "$0";;
	--table) _table;;
	--check) _check;;
	--init) _init; open "$CONFIG_FILE";;
	--cfg) _read_config; open "$CFG_DIR";;
	--github) open "https://github.com/luckman212/alfred-workflow-configurator";;
	--prefs) shift; _prefs "$@";;
esac
