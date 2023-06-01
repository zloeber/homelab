FROM alpine:latest as base

RUN apk add --no-cache curl git make bash
USER app
WORKDIR /app

ADD . . 
RUN \
    ls -al ./
    #  && \
    # git clone https://github.com/asdf-vm/asdf.git ./.asdf && \
    # source ./.asdf/asdf.sh && \
    # ls -al ./
#    ~/asdf/bin/asdf plugin-add task

# RUN task asdf:init && \
#     task asdf:bootstrap && \
#     task aqua:sync

