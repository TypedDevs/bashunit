#!/bin/bash

function clock::now() {
  perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000)'
}

_START_TIME=$(clock::now)

function clock::execution_time() {
  echo $((($(clock::now) - _START_TIME) / 1000))
}
