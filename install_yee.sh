#!/usr/bin/env bash
# Installe la commande « yeelight » et les raccourcis yee-* dans ~/.local/bin
# Usage : ./install_yee.sh [--uninstall]
set -e

REPO_RAW="https://raw.githubusercontent.com/Hoferlukaslh/yeelight-cmd/refs/heads/main"
BIN_DIR="$HOME/.local/bin"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/yeelight-cmd/config"
COMMANDS="on off front-off toggle bright temp bg-on bg-off bg-toggle bg-bright bg-color status set-ip raw help"

if [ "$1" = "--uninstall" ]; then
    rm -f "$BIN_DIR/yeelight"
    for c in $COMMANDS; do rm -f "$BIN_DIR/yee-$c"; done
    echo "Commandes Yeelight supprimées (config conservée : $CONFIG)."
    exit 0
fi

echo "=========================================="
echo "   INSTALLATION DES COMMANDES YEELIGHT    "
echo "=========================================="

# 1. Récupérer le script (local si présent, sinon téléchargé)
mkdir -p "$BIN_DIR"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/yeelight.sh"
if [ -f "$SRC" ]; then
    cp "$SRC" "$BIN_DIR/yeelight"
elif command -v curl >/dev/null; then
    curl -fsSL "$REPO_RAW/yeelight.sh" -o "$BIN_DIR/yeelight"
elif command -v wget >/dev/null; then
    wget -qO "$BIN_DIR/yeelight" "$REPO_RAW/yeelight.sh"
else
    echo "Erreur : curl ou wget requis pour télécharger yeelight.sh" >&2
    exit 1
fi
chmod +x "$BIN_DIR/yeelight"
for c in $COMMANDS; do ln -sf yeelight "$BIN_DIR/yee-$c"; done
echo "✔️  Commandes installées dans $BIN_DIR"

# 2. Ancienne version (fonctions dans ~/.yeelight.sh) : elle masquerait les nouvelles commandes
DEFAULT_IP=""
[ -f "$CONFIG" ] && DEFAULT_IP=$(sed -n 's/^YEE_IP=//p' "$CONFIG" | tr -d '"' | head -n1)
if [ -f "$HOME/.yeelight.sh" ]; then
    [ -z "$DEFAULT_IP" ] && DEFAULT_IP=$(sed -n 's/^YEE_IP="\(.*\)"/\1/p' "$HOME/.yeelight.sh" | head -n1)
    mv "$HOME/.yeelight.sh" "$HOME/.yeelight.sh.bak"
    echo "✔️  Ancienne version déplacée vers ~/.yeelight.sh.bak"
fi

# 3. Demander l'adresse IP (lecture sur le terminal, compatible « curl | bash »)
read -r -p "Adresse IP de la lampe [${DEFAULT_IP:-ex: 192.168.1.22}] : " IP_INPUT < /dev/tty || true
IP_INPUT="${IP_INPUT:-$DEFAULT_IP}"
if [ -n "$IP_INPUT" ]; then
    "$BIN_DIR/yeelight" set-ip "$IP_INPUT"
else
    echo "⚠️  Aucune IP saisie. Plus tard : yee-set-ip <IP>"
fi

# 4. Vérifier que ~/.local/bin est dans le PATH
case ":$PATH:" in
    *":$BIN_DIR:"*) NEED_RELOAD=0 ;;
    *)
        echo -e '\n# Commandes Yeelight\nexport PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo "✔️  $BIN_DIR ajouté au PATH dans ~/.bashrc"
        NEED_RELOAD=1 ;;
esac

echo -e "\n=========================================="
echo "Installation terminée !"
[ "$NEED_RELOAD" = 1 ] && echo "Ouvre un nouveau terminal (ou : source ~/.bashrc)"
echo "Test : yee-status    Aide : yee-help"
echo "=========================================="
