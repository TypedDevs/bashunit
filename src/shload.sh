#!/bin/sh

############################################################
# https://github.com/kndndrj/shload                        #
# Setup the progress bar                                   #
# Usage:                                                   #
#     shload_setup <maximum_value> <loading_symbol>        #
############################################################
shload_setup() {
  # Progress bar variables
  shload_percent=$1
  shload_symbol="$2"

  # Bar width depends on terminal size, max width is 96
  shload_width=$TERMINAL_WIDTH
  shload_delimiter=$shload_percent
  while [ $(($shload_width + 20)) -gt $TERMINAL_WIDTH ]; do
    shload_width=$(($shload_width / 2))
    shload_delimiter=$(($shload_delimiter * 2))
  done

  # If maximum count is less than bar width,
  # adjust symbol width and delimiter (when will the bar update)
  shload_count=$shload_width
  while [ $1 -lt $shload_count ]; do
    shload_delimiter=$(($shload_delimiter * 2))
    shload_symbol="$shload_symbol$shload_symbol"
    shload_count=$(($shload_count / 2))
  done

  # Empty bar and completion variable
  shload_bar=""
  shload_completion_old=0

  # Print the skeleton and save cursor location
  printf "\033[1;032mProgress:\033[0m \033[${shload_width}C\r"
  # Add 1 to the width (less math later)
  shload_width=$(($shload_width + 1))
}

############################################################
# Update the progress bar                                  #
# Usage:                                                   #
#     shload_update <current_value>                        #
############################################################
shload_update() {
  shload_count=$(($1 * 100))
  shload_completion=$(($shload_count / $shload_percent))

  if [ $shload_completion -ne $shload_completion_old ]; then
    if [ $shload_completion -lt 101 ]; then
      # Make the bar itself, by printing the number of characters needed
      shload_bar=$(printf "%0.s${shload_symbol}" $(seq -s " " 1 $(($shload_count / $shload_delimiter))))
    else
      shload_completion=100
      shload_bar=$(printf "%0.s${shload_symbol}" $(seq -s " " 1 $(($((shload_percent * 100)) / shload_delimiter))))
    fi
    shload_completion_old=$shload_completion
  fi

  # Print progress bar and percentage, overwrite the line (\r returns cursor to start)
  printf "\rProgress: [%-${shload_width}s] %d%%\r" "$shload_bar" "$shload_completion"
}
