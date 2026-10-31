#!/usr/bin/env bash
# ==========================================
# CONTRÔLE YEELIGHT (Pure Bash, sans dépendance)
# ==========================================
# Utilisation : yeelight <commande> [args]   (voir « yeelight help »)
# Les liens symboliques yee-on, yee-bg-color... appellent ce script :
# le nom du lien sert de commande (yee-bg-color red == yeelight bg-color red).

YEE_PORT=55443
YEE_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/yeelight-cmd/config"
YEE_DURATION="${YEE_DURATION:-500}"   # Durée de transition en ms

_yee_die() { echo "yeelight: $*" >&2; exit 1; }

# Adresse IP : --ip > variable YEE_IP > fichier de config
_yee_load_ip() {
    if [ -z "$YEE_IP" ] && [ -f "$YEE_CONFIG" ]; then
        YEE_IP=$(sed -n 's/^YEE_IP=//p' "$YEE_CONFIG" | tr -d '"' | head -n1)
    fi
    [ -n "$YEE_IP" ] || _yee_die "aucune IP configurée. Lance : yeelight set-ip <IP>"
}

# Envoie une commande et affiche la réponse JSON (une seule connexion, timeout 3s)
_yee_request() {
    local method="$1" params="$2"
    local payload="{\"id\":1,\"method\":\"$method\",\"params\":[$params]}"
    YEE_IP="$YEE_IP" YEE_PORT="$YEE_PORT" PAYLOAD="$payload" timeout 3 bash -c '
        exec 3<>"/dev/tcp/$YEE_IP/$YEE_PORT" || exit 2
        printf "%s\r\n" "$PAYLOAD" >&3
        # Ignore les notifications ("method":"props") et attend la réponse à id 1
        while read -r -t 2 -u 3 line; do
            line="${line%$'"'"'\r'"'"'}"
            case "$line" in *"\"id\":1,"*) echo "$line"; exit 0 ;; esac
        done
        exit 3
    ' 2>/dev/null
}

# Envoie une commande et vérifie qu'elle a réussi
_yee_send() {
    local reply
    reply=$(_yee_request "$1" "$2")
    case $? in
        0) ;;
        2|124) _yee_die "lampe injoignable ($YEE_IP:$YEE_PORT). Contrôle LAN activé ?" ;;
        *) _yee_die "pas de réponse de la lampe" ;;
    esac
    case "$reply" in
        *'"error"'*)
            local msg="${reply#*\"message\":\"}"
            _yee_die "$1 refusé par la lampe : ${msg%%\"*}" ;;
    esac
}

_yee_effect() { echo "\"smooth\", $YEE_DURATION"; }

_yee_check_percent() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 100 ] \
        || _yee_die "luminosité invalide « $1 » (1 à 100)"
}

# Nom de couleur, #RRGGBB ou R G B -> valeur décimale
_yee_get_color() {
    local hex=""
    if [ "$#" -eq 3 ]; then
        local c
        for c in "$@"; do
            [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -le 255 ] || return 1
        done
        echo $(( ($1 << 16) | ($2 << 8) | $3 ))
        return 0
    fi
    [ "$#" -eq 1 ] || return 1
    case "${1,,}" in
        white|blanc)   hex=FFFFFF ;;
        red|rouge)     hex=FF0000 ;;
        green|vert)    hex=00FF00 ;;
        blue|bleu)     hex=0000FF ;;
        yellow|jaune)  hex=FFFF00 ;;
        purple|violet) hex=800080 ;;
        orange)        hex=FF8000 ;;
        pink|rose)     hex=FF69B4 ;;
        cyan)          hex=00FFFF ;;
        magenta)       hex=FF00FF ;;
        \#*|[0-9a-f]*) hex="${1#\#}" ;;
    esac
    [[ "$hex" =~ ^[0-9A-Fa-f]{6}$ ]] || return 1
    echo $(( 16#$hex ))
}

yee_status() {
    local reply
    reply=$(_yee_request get_prop '"power","bright","ct","bg_power","bg_bright","bg_rgb","name"') \
        || _yee_die "lampe injoignable ($YEE_IP:$YEE_PORT)"
    case "$reply" in *'"result"'*) ;; *) _yee_die "réponse inattendue : $reply" ;; esac
    reply="${reply#*\"result\":[}"
    reply="${reply%]*}"
    reply="${reply//\"/}"
    local power bright ct bg_power bg_bright bg_rgb name
    IFS=, read -r power bright ct bg_power bg_bright bg_rgb name <<< "$reply"
    echo "Lampe $YEE_IP${name:+ ($name)}"
    echo "  Principale : $power, luminosité ${bright}%, ${ct} K"
    if [ -n "$bg_power" ]; then
        printf '  Arrière    : %s, luminosité %s%%, couleur #%06X\n' "$bg_power" "$bg_bright" "${bg_rgb:-0}"
    fi
}

yee_help() {
    cat <<EOF

==========================================
   CONTRÔLE YEELIGHT (IP: ${YEE_IP:-non configurée})
==========================================
Utilisation : yeelight [--ip IP] <commande>   ou   yee-<commande>

LAMPE PRINCIPALE (Avant)
  yee-on              : Allumer la lampe
  yee-off             : Éteindre l'avant ET l'arrière
  yee-front-off       : Éteindre l'avant, garder l'arrière allumé
  yee-toggle          : Basculer allumé/éteint
  yee-bright <%>      : Régler la luminosité (1-100)
  yee-temp <valeur>   : Température (chaud, neutre, froid, ou 1700-6500 K)

BACKGROUND (Arrière / Ambilight)
  yee-bg-on           : Allumer
  yee-bg-off          : Éteindre
  yee-bg-toggle       : Basculer allumé/éteint
  yee-bg-bright <%>   : Régler la luminosité (1-100)
  yee-bg-color <c>    : Couleur : nom (red, orange, blue...), #FF8000 ou R G B

AUTRES
  yee-status          : Afficher l'état de la lampe
  yee-set-ip <IP>     : Enregistrer l'IP de la lampe
  yee-raw <méthode> [params]   : Commande brute (ex: yee-raw set_power '"on"')
  yee-help            : Ce menu

Variables : YEE_IP (remplace l'IP configurée), YEE_DURATION (transition en ms)
EOF
}

main() {
    local cmd
    case "$(basename "$0")" in
        yee-*) cmd="$(basename "$0")"; cmd="${cmd#yee-}"; cmd="${cmd%.sh}" ;;
        *)
            if [ "$1" = "--ip" ]; then
                [ -n "$2" ] || _yee_die "--ip demande une adresse"
                YEE_IP="$2"; shift 2
            fi
            cmd="${1:-help}"; shift ;;
    esac

    case "$cmd" in
        help|-h|--help)
            [ -f "$YEE_CONFIG" ] && [ -z "$YEE_IP" ] && YEE_IP=$(sed -n 's/^YEE_IP=//p' "$YEE_CONFIG" | tr -d '"')
            yee_help; return ;;
        set-ip)
            [ -n "$1" ] || _yee_die "usage : yeelight set-ip <IP>"
            mkdir -p "$(dirname "$YEE_CONFIG")"
            echo "YEE_IP=\"$1\"" > "$YEE_CONFIG"
            echo "IP enregistrée : $1 ($YEE_CONFIG)"; return ;;
    esac

    _yee_load_ip
    case "$cmd" in
        on)        _yee_send set_power "\"on\", $(_yee_effect)" ;;
        off)       _yee_send set_power "\"off\", $(_yee_effect)"
                   _yee_send bg_set_power "\"off\", $(_yee_effect)" ;;
        front-off) _yee_send set_power "\"off\", $(_yee_effect)"
                   _yee_send bg_set_power "\"on\", $(_yee_effect)" ;;
        toggle)    _yee_send toggle "" ;;
        bright)
            _yee_check_percent "$1"
            _yee_send set_bright "$1, $(_yee_effect)" ;;
        temp)
            local ct="$1"
            case "${1,,}" in
                chaud|warm)  ct=2700 ;;
                neutre|mid)  ct=4000 ;;
                froid|cold)  ct=6500 ;;
            esac
            if ! [[ "$ct" =~ ^[0-9]+$ ]] || [ "$ct" -lt 1700 ] || [ "$ct" -gt 6500 ]; then
                _yee_die "usage : yee-temp <chaud|neutre|froid|1700-6500>"
            fi
            _yee_send set_ct_abx "$ct, $(_yee_effect)" ;;
        bg-on)     _yee_send bg_set_power "\"on\", $(_yee_effect)" ;;
        bg-off)    _yee_send bg_set_power "\"off\", $(_yee_effect)" ;;
        bg-toggle) _yee_send bg_toggle "" ;;
        bg-bright)
            _yee_check_percent "$1"
            _yee_send bg_set_bright "$1, $(_yee_effect)" ;;
        bg-color)
            local rgb
            rgb=$(_yee_get_color "$@") \
                || _yee_die "usage : yee-bg-color <nom|#RRGGBB|R G B> (ex: yee-bg-color orange)"
            _yee_send bg_set_rgb "$rgb, $(_yee_effect)" ;;
        status)    yee_status ;;
        raw)
            [ -n "$1" ] || _yee_die "usage : yee-raw <méthode> [params JSON]"
            _yee_request "$1" "$2" || _yee_die "lampe injoignable ($YEE_IP:$YEE_PORT)" ;;
        *) _yee_die "commande inconnue « $cmd ». Voir : yeelight help" ;;
    esac
}

main "$@"
