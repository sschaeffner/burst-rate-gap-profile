#!/bin/bash

REPO_DIR=/local/repository
LOG_DIR=$REPO_DIR

$REPO_DIR/dut/setup.sh &> $LOG_DIR/dut_setup_log.txt