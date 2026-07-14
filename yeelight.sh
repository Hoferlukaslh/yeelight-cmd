# ==========================================
# CONTRÔLE YEELIGHT
# ==========================================
YEE_IP="192.168.1.22"

# ==========================================
# CONTRÔLE YEELIGHT (IP: 192.168.1.22)
# ==========================================
YEE_IP="192.168.1.22"

# 1. Fonction utilitaire invisible (Pure Bash, sans netcat)
_yee_send() {
    # Exécution avec un timeout de 1s pour éviter que le terminal ne bloque si la lampe est injoignable
    timeout 1 bash -c "echo -ne '$1\r\n' > /dev/tcp/$YEE_IP/55443" 2>/dev/null
    sleep 0.5
    timeout 1 bash -c "echo -ne '$1\r\n' > /dev/tcp/$YEE_IP/55443" 2>/dev/null
}

# 2. Fonction utilitaire pour traduire les noms de couleurs en décimal
_yee_get_color() {
    case "${1,,}" in
        white)  echo "16777215" ;;
        red)    echo "16711680" ;;
        green)  echo "65280" ;;
        blue)   echo "255" ;;
        yellow) echo "16776960" ;;
        purple) echo "8388736" ;;
        orange) echo "16753920" ;;
        *)      echo "" ;;
    esac
}

# --- Allumer / Éteindre ---
alias yee-on="_yee_send '{\"id\":1,\"method\":\"set_power\",\"params\":[\"on\", \"smooth\", 500]}'"
alias yee-bg-on="_yee_send '{\"id\":1,\"method\":\"bg_set_power\",\"params\":[\"on\", \"smooth\", 500]}'"
alias yee-bg-off="_yee_send '{\"id\":1,\"method\":\"bg_set_power\",\"params\":[\"off\", \"smooth\", 500]}'"

# --- Luminosité (1 à 100) ---
yee-bright() {
    if [ -z "$1" ]; then echo "Erreur: Précise un % (ex: yee-bright 50)"; return 1; fi
    _yee_send '{"id":1,"method":"set_bright","params":['"$1"', "smooth", 500]}'
}
yee-bg-bright() {
    if [ -z "$1" ]; then echo "Erreur: Précise un % (ex: yee-bg-bright 50)"; return 1; fi
    _yee_send '{"id":1,"method":"bg_set_bright","params":['"$1"', "smooth", 500]}'
}

# --- Température Lampe principale (Kelvin ou Mots-clés) ---
yee-temp() {
    local ct_val="$1"
    # Mots-clés rapides
    case "${1,,}" in
        chaud|warm)  ct_val=2700 ;;
        neutre|mid)  ct_val=4000 ;;
        froid|cold)  ct_val=6500 ;;
    esac

    # Vérifie si la valeur est bien un nombre
    if ! [[ "$ct_val" =~ ^[0-9]+$ ]]; then
        echo "Usage 1 : yee-temp <chaud|neutre|froid>"
        echo "Usage 2 : yee-temp <valeur en Kelvin> (ex: 2700 à 6500)"
        return 1
    fi
    _yee_send '{"id":1,"method":"set_ct_abx","params":['"$ct_val"', "smooth", 500]}'
}

# --- Couleurs Background (Nom ou RGB) ---
yee-bg-color() {
    local dec_val=""
    if [ "$#" -eq 1 ]; then
        dec_val=$(_yee_get_color "$1")
        if [ -z "$dec_val" ]; then echo "Couleur inconnue."; return 1; fi
    elif [ "$#" -eq 3 ]; then
        dec_val=$(( ($1 << 16) | ($2 << 8) | $3 ))
    else
        echo "Usage 1 : yee-bg-color <white|red|green|blue|yellow|purple|orange>"
        echo "Usage 2 : yee-bg-color <R> <G> <B> (ex: yee-bg-color 255 0 0)"
        return 1
    fi
    _yee_send '{"id":1,"method":"bg_set_rgb","params":['"$dec_val"', "smooth", 500]}'
}

# --- Éteindre l'avant et forcer le BG allumé ---
yee-front-off() {
    _yee_send '{"id":1,"method":"set_power","params":["off", "smooth", 500]}'
    _yee_send '{"id":1,"method":"bg_set_power","params":["on", "smooth", 500]}'
}

yee-off() {
    _yee_send '{"id":1,"method":"set_power","params":["off", "smooth", 500]}'
    _yee_send '{"id":1,"method":"bg_set_power","params":["off", "smooth", 500]}'
}

# --- Menu d'aide ---
yee-help() {
    echo -e "\n=========================================="
    echo -e "   CONTRÔLE YEELIGHT (IP: $YEE_IP)"
    echo -e "==========================================\n"
    echo -e "LAMPE PRINCIPALE (Avant)"
    echo -e "  yee-on            : Allumer la lampe"
    echo -e "  yee-off           : Éteindre la lampe (peut impacter le BG)"
    echo -e "  yee-front-off     : Éteindre l'avant ET garder le BG allumé"
    echo -e "  yee-bright <%>    : Régler la luminosité (1-100)"
    echo -e "  yee-temp <valeur> : Régler la température (chaud, neutre, froid, ou 2700-6500)\n"
    echo -e "BACKGROUND (Arrière / Ambilight)"
    echo -e "  yee-bg-on         : Allumer"
    echo -e "  yee-bg-off        : Éteindre"
    echo -e "  yee-bg-bright <%> : Régler la luminosité (1-100)"
    echo -e "  yee-bg-color <c>  : Changer la couleur (white, red, green... ou RGB)\n"
}o -e "                      ou en RGB (ex: yee-bg-color 255 0 255)\n"
}
