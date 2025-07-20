#!/bin/bash
set -e

rm -rf cache
rm -rf config

docker-compose build --no-cache
docker-compose up 