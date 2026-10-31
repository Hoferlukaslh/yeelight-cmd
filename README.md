# yeelight-cmd
cmd utility for my yeelight lamp

## Télécharger et lancer le script
### Windows 
```ps 
iex (irm "https://raw.githubusercontent.com/Hoferlukaslh/yeelight-cmd/refs/heads/main/Install-Yeelight.ps1")
. $PROFILE

```

### Linux
#### CURL
```bash
curl -O https://raw.githubusercontent.com/Hoferlukaslh/yeelight-cmd/refs/heads/main/install_yee.sh && chmod +x install_yee.sh && ./install_yee.sh

```

#### WGET
```bash
wget https://raw.githubusercontent.com/Hoferlukaslh/yeelight-cmd/refs/heads/main/install_yee.sh && chmod +x install_yee.sh && ./install_yee.sh

```

L'installation ne demande aucune dépendance (Bash pur, via `/dev/tcp`) : elle copie
`yeelight` et les raccourcis `yee-*` dans `~/.local/bin` et enregistre l'IP de la lampe
dans `~/.config/yeelight-cmd/config`. Désinstaller : `./install_yee.sh --uninstall`.

## Commandes (Linux)
| Commande | Effet |
|---|---|
| `yee-on` / `yee-off` / `yee-toggle` | Allumer / éteindre tout / basculer |
| `yee-front-off` | Éteindre l'avant, garder l'arrière allumé |
| `yee-bright <1-100>` | Luminosité principale |
| `yee-temp <chaud\|neutre\|froid\|1700-6500>` | Température principale |
| `yee-bg-on` / `yee-bg-off` / `yee-bg-toggle` | Éclairage arrière |
| `yee-bg-bright <1-100>` | Luminosité arrière |
| `yee-bg-color <nom\|#RRGGBB\|R G B>` | Couleur arrière (ex: `orange`, `#FF8000`, `255 128 0`) |
| `yee-status` | État de la lampe |
| `yee-set-ip <IP>` | Changer l'IP enregistrée |
| `yee-raw <méthode> [params]` | Commande brute du protocole Yeelight |

Chaque commande existe aussi sous la forme `yeelight <commande>` (ex: `yeelight --ip 192.168.1.30 status`).
