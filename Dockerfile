FROM alpine:latest as base

RUN apk add --no-cache curl git make bash
USER app
WORKDIR /app

ADD . . 
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf
RUN source ~/.asdf/asdf.sh && \
    ~/.asdf/bin/asdf plugin-add task \
    task asdf:init && \
    ls -al
