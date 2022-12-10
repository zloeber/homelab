#!/bin/bash

docker \
  run -it \
  --rm \
  --name private_share \
  -p 139:139 \
  -p 445:445 \
  -v /home/zloeber/Share/media:/srv \
  -d dperson/samba \
    -p \
    -u "user1;pass1" \
    -s "movies;/srv;yes;yes;no;user1"
