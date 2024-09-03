#!/bin/bash

function clock::now() {
  if perl -MTime::HiRes -e "" > /dev/null 2>&1; then
    perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
  elif [[ "$_OS" != "OSX" ]]; then
    date +%s%N
  else
    echo ""
  fi
}

_START_TIME=$(clock::now)

function clock::runtime_in_milliseconds() {
  end_time=$(clock::now)
  if [[ -n $end_time ]]; then
    echo $(( end_time - _START_TIME ))
  else
    echo ""
  fi
}
