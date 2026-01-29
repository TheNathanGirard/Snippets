#!/bin/bash
docker-compose down --remove-orphans
docker volume rm elastic_esdata
