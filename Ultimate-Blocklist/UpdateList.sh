#!/usr/bin/env bash
# A simple script that downloads all blacklists in the list, and saves them in one mega-list
# Written by: Adam Walsh
# Written on 2/24/14

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="${SCRIPT_DIR}/../public/blocklist.txt"

while getopts ":c:zh" opt; do
  case $opt in
    c)
      CONF_DIR=$OPTARG
      ;;
    z)
      zip=true
      ;;
    h)
      echo -ne "Usage: -c config dir\n\t-z gzip result file ( doesn't work with daemon 2.84 )\n"
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [[ -n "${CONF_DIR:-}" ]]; then
  if [[ ! -d "$CONF_DIR" ]]; then
    echo "Config directory does not exist: $CONF_DIR" >&2
    exit 1
  fi
  path_to_config=$CONF_DIR
elif [[ "$OSTYPE" =~ darwin ]]; then
  path_to_config="$HOME/Library/Application Support/Transmission"
else
  path_to_config="$HOME/.config/transmission"
fi

blocklist_path="$path_to_config/blocklists"

TITLEs=("Bluetack LVL 1" "Bluetack LVL 2" "Bluetack LVL 3" "Bluetack edu" "Bluetack ads"
"Bluetack spyware" "Bluetack proxy" "Bluetack badpeers" "Bluetack Microsoft" "Bluetack spider"
"Bluetack hijacked" "Bluetack dshield" "Bluetack forumspam" "Bluetack webexploit" "TBG Primary Threats"
"TBG General Corporate Range" "TBG Buissness ISPs" "TBG Educational Institutions"
)
URLs=("https://list.iblocklist.com/?list=bt_level1&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_level2&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_level3&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_edu&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_ads&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_spyware&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_proxy&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_templist&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_microsoft&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_spider&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_hijacked&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=bt_dshield&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=ficutxiwawokxlcyoeye&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=ghlzqtqxnzctvvajwwag&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=ijfqtofzixtwayqovmxn&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=ecqbsykllnadihkdirsh&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=jcjfaxgyyshvdbceroxf&fileformat=p2p&archiveformat=gz"
"https://list.iblocklist.com/?list=lljggjrpmefcwqknpalp&fileformat=p2p&archiveformat=gz"
)

if (( ${#TITLEs[@]} != ${#URLs[@]} )); then
  echo "Internal error: TITLEs and URLs arrays are out of sync." >&2
  exit 1
fi

if tty -s; then
  info() {
    echo "$@"
  }
else
  info() {
    true
  }
fi

die() {
  echo "$@" >&2
  exit 1
}

tmp_gz=""
tmp_list=""
downloads_ok=0

cleanup() {
  if [[ -n "$tmp_gz" && -f "$tmp_gz" ]]; then
    rm -f "$tmp_gz"
  fi
  if [[ -n "$tmp_list" && -f "$tmp_list" ]]; then
    rm -f "$tmp_list"
  fi
}

trap cleanup EXIT

mkdir -p "$(dirname "$LIST")"
tmp_list="$(mktemp "${LIST}.XXXXXX")"
tmp_gz="$(mktemp)"

if wget=$(command -v wget); then
  download() {
    $wget -q --https-only --tries=2 --connect-timeout=2 --read-timeout=5 -O "$tmp_gz" "$1"
  }
elif curl=$(command -v curl); then
  download() {
    $curl -fsSL --max-time 5 --proto '=https' -o "$tmp_gz" "$1"
  }
else
  die "$0: 'wget' or 'curl' required but not found. Aborting."
fi

index=0
for url in "${URLs[@]}"; do
  title="${TITLEs[$index]}"
  info "Downloading list $title"
  if download "$url"; then
    if [[ ! -s "$tmp_gz" ]]; then
      info "Skipping $title: empty download"
    elif ! gzip -t "$tmp_gz" 2>/dev/null; then
      info "Skipping $title: download is not valid gzip"
    else
      info "Adding IP's to list file..."
      gunzip -c "$tmp_gz" >> "$tmp_list" || die "Cannot append to list"
      downloads_ok=$((downloads_ok + 1))
      info ""
    fi
  else
    info "Skipping $title: download failed"
  fi
  : >"$tmp_gz"
  index=$((index + 1))
done

if (( downloads_ok == 0 )); then
  die "No lists downloaded; keeping existing blocklist at $LIST"
fi

mv "$tmp_list" "$LIST"
tmp_list=""
chmod 644 "$LIST"

wc -l "$LIST" || die "Cannot count lines"

info "Done!"
info "Restart transmission"
