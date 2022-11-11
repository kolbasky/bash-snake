#!/usr/bin/env bash
shopt -s extglob 2> /dev/null 
setopt extended_glob 2> /dev/null 
setopt KSH_ARRAYS 2> /dev/null 
trap "tput cnorm; tput sgr0; stty echo; tput rmcup; exit 1" SIGINT SIGTERM EXIT
stty -echo
tput smcup
tput civis

bound_color=3
snake_color=2
appale_color=1
score_color=6
clock_color=8
snake_head="@"
snake_tail="0"
apple="@"
fps_step=5
width=`tput cols`
height=`tput lines`
if [[ -z $1 ]];then 
    blocks=1; tputseta="setab"; 
else 
    blocks=0; tputseta="setaf" ;
fi

welcome() {
    tput sgr0
    line="Snake game"
    l=${#line}
    tput cup $((height / 2 - 2)) $((width / 2 - $l / 2))
    printf -- "$(tput smso)$(tput setaf $bound_color)$line$(tput sgr0)"
    line="WASD/Arrows to change direction"
    l=${#line}
    tput cup $((height / 2)) $((width / 2 - $l / 2))
    printf -- "$(tput setaf $bound_color)$line$(tput sgr0)"
    line="-/+ to change speed"
    l=${#line}
    tput cup $((height / 2 + 1)) $((width / 2 - $l / 2))
    printf -- "$(tput setaf $bound_color)$line$(tput sgr0)"
    line="P to pause"
    l=${#line}
    tput cup $((height / 2 + 2)) $((width / 2 - $l / 2))
    printf -- "$(tput setaf $bound_color)$line$(tput sgr0)"
    read -s -n 1
}

die() {
    tput sgr0
    # enable gore :-)
    if [[ ${pos[0]} -eq 0 ]];then
        tput cup $((${pos[1]}+1)) $((${pos[0]}))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)#\\"
        tput cup $((${pos[1]}-1)) $((${pos[0]}))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)#/"
    fi
    if [[ ${pos[0]} -eq $((width-1)) ]];then
        tput cup $((${pos[1]}+1)) $((${pos[0]}-1))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)/#"
        tput cup $((${pos[1]}-1)) $((${pos[0]}-1))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)\\#"
    fi
    if [[ ${pos[1]} -eq 1 ]];then
        tput cup $((${pos[1]})) $((${pos[0]}-1))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)#@#"
        tput cup $((${pos[1]}+1)) $((${pos[0]}+1))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)\\"
        tput cup $((${pos[1]}+1)) $((${pos[0]}-1))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)/"
    fi
    if [[ ${pos[1]} -eq $((height-1)) ]];then
        tput cup $((${pos[1]}1)) $((${pos[0]}-1))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)#\\#"
        tput cup $((${pos[1]}-1)) $((${pos[0]}+1))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)/"
        tput cup $((${pos[1]}-1)) $((${pos[0]}-1))
        printf -- "$(tput $tputseta 1)$(tput setaf 1)\\"
    fi
    tput cup ${pos[1]} ${pos[0]}
    printf -- "$(tput $tputseta 1)$(tput setaf 1)@$(tput sgr0)"
    game_over="GAME OVER!"
    l=${#game_over}
    tput cup $((height / 2 - 2)) $((width / 2 - $l / 2))
    printf -- "$(tput blink)$(tput setaf 1)$game_over$(tput sgr0)"
    result="Score: $score"
    l=${#result}
    tput cup $((height / 2 - 1)) $((width / 2 - $l / 2))
    printf -- "$(tput blink)$(tput setaf 1)$result$(tput sgr0)"
    result="Press R to restart, Q to quit"
    l=${#result}
    tput cup $((height / 2 + 1)) $((width / 2 - $l / 2))
    printf -- "$(tput blink)$(tput setaf 1)$result$(tput sgr0)"
    while true; do
        read -n 1 -s key
        if [[ ${key,,} == "r" ]] || [[ ${key,,} == "к" ]]; then
            key=""
            main
        elif [[ ${key,,} == "q" ]] || [[ ${key,,} == "й" ]]; then
            exit 0
        fi
    done
    main
}

draw_boundaries() {
    tput sgr0
    tput civis
    width=`tput cols`
    height=`tput lines`
    i=0
    clear
    while [[ $i -le $width ]];do
        tput cup 1 $i
        printf -- "$(tput $tputseta $bound_color)$(tput setaf $bound_color)#"
        tput cup $height $i
        printf -- "$(tput $tputseta $bound_color)$(tput setaf $bound_color)#"
        i=$((i+1))
    done
    i=1
    while [[ $i -le $height ]];do
        tput cup $i 0
        printf -- "$(tput $tputseta $bound_color)$(tput setaf $bound_color)#"
        tput cup $i $width
        printf -- "$(tput $tputseta $bound_color)$(tput setaf $bound_color)#"
        i=$((i+1))
    done
}

read_key() {
    escape_char=$(printf "\u1b")
    read -t 0.001 -r -s -n 1 key 2> /dev/null || read -r -t 0.001 -s -k 1 key 2> /dev/null
    if [[ $key == $escape_char ]]; then
        read -t 0.001 -r -s -n 2 key_arrow 2> /dev/null || read -r -t 0.001 -s -k 2 key_arrow 2> /dev/null
    fi
    #read -t 0.001 -r -s
    if [[ ${key,,} == "w" ]] || [[ ${key,,} == "ц" ]] || [[ ${key_arrow} == '[A' ]];then 
        if [[ yspeed -ne 1 ]]; then
            yspeed=-1; xspeed=0;
        fi
    elif [[ ${key,,} == "a" ]] || [[ ${key,,} == "ф" ]] || [[ ${key_arrow} == '[D' ]];then
        if [[ xspeed -ne 1 ]]; then
            xspeed=-1; yspeed=0;
        fi
    elif [[ ${key,,} == "s" ]] || [[ ${key,,} == "ы" ]] || [[ ${key_arrow} == '[B' ]];then 
        if [[ yspeed -ne -1 ]]; then
            yspeed=1; xspeed=0;
        fi
    elif [[ ${key,,} == "d" ]] || [[ ${key,,} == "в" ]] || [[ ${key_arrow} == '[C' ]];then 
        if [[ xspeed -ne -1 ]]; then
            xspeed=1; yspeed=0;
        fi
    elif [[ ${key:-0} == "-" ]];then 
        fps=$((fps - $fps_step));
    elif [[ ${key:-0} == "=" ]];then 
        fps=$((fps + $fps_step));
    elif [[ ${key:-0} == "+" ]];then 
        fps=$((fps + $fps_step));
    elif [[ ${key,,} == "r" ]] || [[ ${key,,} == "к" ]];then 
        draw_boundaries
    elif [[ ${key,,} == "p" ]] || [[ ${key,,} == "з" ]];then 
        read -s -n 1
    fi 
    key="" 
    key_arrow=""
    if [[ $fps -le 0 ]]; then fps=5; fi 
    if [[ $fps -gt 200 ]]; then fps=200; fi 
    if [[ $xspeed -eq 0 ]]; then
        sleep=`printf "scale = 3; 1 / $fps * 2\n" | bc`
    else
        sleep=`printf "scale = 3; 1 / $fps\n" | bc`
    fi
}

draw_screen() {
    tput sgr0
    if [[ $width -ne `tput cols` ]] || [[ $height -ne `tput lines` ]]; then
        draw_boundaries
    fi
    i=0
    last=$((${#prevpos[@]}-1))
    tput cup ${prevpos[$last]} ${prevpos[$((last-1))]}
    printf -- "$(tput sgr0) "
    while [[ $i -lt ${#pos[@]} ]]; do
        tput cup $((${pos[$((i+1))]})) ${pos[$i]}
        if [[ $i -eq 0 ]]; then
            if [[ $blocks == "1" ]]; then
                if [[ $xspeed -eq 0 ]];then
                    printf -- "$(tput $tputseta $snake_color)$(tput setaf 0)⠒$(tput sgr0)"
                elif [[ $yspeed -eq 0 ]];then
                    printf -- "$(tput $tputseta $snake_color)$(tput setaf 0):$(tput sgr0)"
                fi
            else
                printf -- "$(tput setaf $snake_color)$snake_head$(tput sgr0)"
            fi
        else
            if [[ $(($i % 4)) -eq 2 ]] && [[ $blocks == "1" ]]; then
                printf -- "$(tput $tputseta $snake_color)$(tput setaf 3)$snake_tail$(tput sgr0)"
            # elif [[ $(($i % 4)) -eq 2 ]] && [[ $blocks == "0" ]]; then
            #     printf -- "$(tput $tputseta $snake_color)$(tput setaf $snake_color)$(tput blink)$snake_tail$(tput sgr0)"
            else
                printf -- "$(tput $tputseta $snake_color)$(tput setaf $snake_color)$snake_tail$(tput sgr0)"
            fi
        fi
        i=$((i+2))
    done
    tput cup $a_ypos $a_xpos && printf -- "$(tput setaf $appale_color)$(tput $tputseta $appale_color)$apple$(tput sgr0)"
    score_board="Score: $score"
    l=${#score_board}
    tput cup 0 $(($width / 2 - $l / 2))
    if [[ $blocks -eq 1 ]];then
        printf -- "$(tput setaf $score_color)$(tput smso)$score_board$(tput sgr0)"
    else
        printf -- "$(tput setaf $score_color)$score_board$(tput sgr0)"
    fi
    tput cup 0 0
    if [[ $blocks -eq 1 ]];then
        printf -- "$(tput setaf $clock_color)$(tput smso)`date +%H:%M:%S`$(tput sgr0)"
    else
        printf -- "$(tput setaf $clock_color)`date +%H:%M:%S`$(tput sgr0)"
    fi
    speedometer="Speed: ${fps}"
    l=${#speedometer}
    tput cup 0 $((width - $l))
    if [[ $blocks -eq 1 ]];then
        printf -- "$(tput setaf $clock_color)$(tput smso)$speedometer$(tput sgr0)"
    else
        printf -- "$(tput setaf $clock_color)$speedometer$(tput sgr0)"
    fi
}

move_snake() {
    i=0
    prevpos=("${pos[@]}")
    while [[ $i -lt ${#pos[@]} ]]; do
        if [[ $i -eq 0 ]];then
            pos[0]=$((${pos[0]} + $xspeed))
            pos[1]=$((${pos[1]} + $yspeed))
        else
            pos[$i]=$((${prevpos[$((i-2))]}))
            pos[$((i+1))]=$((${prevpos[$((i-1))]}))
        fi
        i=$((i+2))
    done
}

eat_apple() {
    if [[ ${pos[0]} -eq a_xpos ]] && [[ ${pos[1]} -eq a_ypos ]];then
        pos+=(${pos[$(($last-1))]})
        pos+=(${pos[$last]})
        a_xpos=$((1 + $RANDOM % ($width - 2) ))
        a_ypos=$((2 + $RANDOM % ($height - 3) ))
        score=$((score+1))
        if [[ $((score % 5)) -eq 0 ]];then
            fps=$((fps+10))
        fi
        i=2
        while [[ $i -lt ${#pos[@]} ]];do
            if [[ ${pos[$i]} -eq a_xpos ]] && [[ ${pos[$((i+1))]} -eq a_ypos ]];then
                a_xpos=$((1 + $RANDOM % ($width - 2) ))
                a_ypos=$((2 + $RANDOM % ($height - 3) ))
                i=2
            else
                i=$((i+2))
            fi
        done
    fi
}

detect_collision() {
    if [[ ${pos[0]} -eq 0 ]] ||
    [[ ${pos[0]} -eq $((width-1)) ]] ||
    [[ ${pos[1]} -eq 1 ]] ||
    [[ ${pos[1]} -eq $((height-1)) ]]
    then
         die
    fi
    i=2
    while [[ $i -lt ${#pos[@]} ]]; do
        if [[ ${pos[0]} -eq ${pos[$i]} ]] && 
        [[ ${pos[1]} -eq ${pos[$((i+1))]} ]]
        then
            die
        fi
        i=$((i+2))
    done
}

main() {
    tput civis
    width=`tput cols`
    height=`tput lines`
    xspeed=1
    yspeed=0
    pos=($((width / 4)) $((height / 2)))
    fps=10
    sleep=`printf "scale = 3; 1 / $fps\n" | bc`
    a_xpos=$((1 + $RANDOM % ($width - 2) ))
    a_ypos=$((2 + $RANDOM % ($height - 3) ))
    score=0
    draw_boundaries
    while true; do
        read_key
        move_snake
        detect_collision
        eat_apple
        draw_screen
        sleep $sleep  
    done
}
welcome
main
