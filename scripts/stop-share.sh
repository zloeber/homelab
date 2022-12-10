#!/bin/bash

docker \
  stop private_share

sudo chown -R $(whoami):$(whoami) ~/Share/media
