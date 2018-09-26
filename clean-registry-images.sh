#!/usr/bin/env bash
#########################################################################
# File Name: cronjob.sh
# Author: longhui
# Created Time: 2018-08-15 14:30:36
#########################################################################

WORK_DIR="/lain/app"
# keep latest 200 tags for image
python2 ${WORK_DIR}/clean-registry-images.py  --delete --num 200
registry garbage-collect ${WORK_DIR}/config.yaml
