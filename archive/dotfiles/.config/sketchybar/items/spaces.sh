#!/bin/bash

#!/bin/bash

SPACE_ICONS=("~" "Web" "Chat" "Dev" "Personal" "Media" "Others")

SPACE=(
    icon.padding_left=12
    icon.padding_right=2
    icon.font="$WHITE:Bold:12.0"
    icon.color=$WHITE
    icon.highlight_color=$WHITE
    # label.font="$FONT:Bold:12.0"
    label.font="sketchybar-app-font:Regular:12.0"
    label.padding_left=2
    label.padding_right=12
    label.color=$FOAM
    label.drawing=on
    background.height=26
    background.color=$MUTED
    background.corner_radius=5
    background.drawing=off
    script="$PLUGIN_DIR/spaces.sh"
)

sid=0
for i in "${!SPACE_ICONS[@]}"
do
    sid=$(($i+1))
    sketchybar --add space space.$sid left
    sketchybar --set space.$sid "${SPACE[@]}"
    sketchybar --set space.$sid associated_space=$sid
    sketchybar --set space.$sid icon=${SPACE_ICONS[i]}
done

#sketchybar --add bracket spaces '/space\..*/' --set spaces background.color=$OVERLAY background.corner_radius=10 background.height=26

#sketchybar --add item yabai_mode left --set yabai_mode update_freq=3 script="$PLUGIN_DIR/yabai.sh" click_script="$PLUGIN_DIR/yabai_click.sh" --subscribe yabai_mode space_change

#sketchybar --add item separator left --set separator icon="$SPACE_SEPARATOR" icon.font="$FONT:Bold:12.0" background.padding_left=4 background.padding_right=4 label.drawing=off icon.color=$GOLD script="$PLUGIN_DIR/space_windows.sh" --subscribe separator space_windows_change