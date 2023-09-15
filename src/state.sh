#!/bin/bash

STATE="/dev/shm/_BASHUNIT_STATE"
echo "" > $STATE

function getTestsPassed() {
  grep -o "P" $STATE | wc -l
}

function addTestsPassed() {
  echo -n "P" >> $STATE
}

function getTestsFailed() {
  grep -o "F" $STATE | wc -l
}

function addTestsFailed() {
  echo -n "F" >> $STATE
}

function getAssertionsPassed() {
  grep -o "p" $STATE | wc -l
}

function addAssertionsPassed() {
  echo -n "p" >> $STATE
}

function getAssertionsFailed() {
  grep -o "f" $STATE | wc -l
}

function addAssertionsFailed() {
  echo -n "f" >> $STATE
}
