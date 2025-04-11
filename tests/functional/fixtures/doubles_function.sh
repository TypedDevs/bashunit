#!/bin/bash

function top_mem() {
  ps -eo cmd,%mem --sort=-%mem | awk '$2 >= 1.0 {print $0}' | head -n 3
}
