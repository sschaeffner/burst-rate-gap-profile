#!/bin/bash

REPO_DIR=/local/repository
LOG_DIR=$REPO_DIR

$REPO_DIR/loadgen/setup.sh &> $LOG_DIR/loadgen_setup_log.txt