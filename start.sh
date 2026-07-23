#!/bin/sh
cd "$(dirname "$0")" || exit 1
(sleep 0.3; open "http://127.0.0.1:8080/lodeRunner.html") &
python3 -m http.server 8080 --bind 127.0.0.1
