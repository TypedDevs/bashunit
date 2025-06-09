#!/usr/bin/env bash

ps | awk '$2 >= 1.0 {print $0}' | head -n 3
