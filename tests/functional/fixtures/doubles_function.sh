#!/usr/bin/env bash

function top_mem() {
  ps | awk '$2 >= 1.0 {print $0}' | head -n 3
}
