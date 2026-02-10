#!/bin/bash

source "$CONFIG_DIR/colors.sh"

if [ "$SELECTED" = "true" ]; then
    WIDTH="0"
    ICON_PADDING_RIGHT=12
    BG_COLOR=$MUTED
else
    WIDTH="dynamic"
    ICON_PADDING_RIGHT=2
    BG_COLOR=$OVERLAY
fi

sketchybar --animate tanh 20 --set $NAME icon.highlight=$SELECTED icon.padding_right=$ICON_PADDING_RIGHT label.width=$WIDTH background.color=$BG_COLOR