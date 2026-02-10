#!/bin/bash

sketchybar --add item time right \
           --set time update_freq=2 \
                      icon.padding_right=0 \
                      label.padding_left=0 \
                      script="$PLUGIN_DIR/time.sh" \
           \
           --add item date right \
           --set date update_freq=60 \
                      background.color=$MUTED \
                      label.color=$WHITE \
                      label.font="Hack Nerd Font:Semibold:12" \
                      icon.padding_right=0 \
                      label.padding_left=0 \
                      background.height=24 \
                      background.corner_radius=4 \
                      script="$PLUGIN_DIR/date.sh"