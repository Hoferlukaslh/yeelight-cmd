Write-Host "=========================================="
Write-Host "   INSTALLATION DES COMMANDES YEELIGHT    "
Write-Host "=========================================="

# 1. Demander l'adresse IP
$IP_INPUT = Read-Host "Entrez l'adresse IP de la lampe (ex: 192.168.1.22)"

# Definition des chemins (equivalent de ~/.bashrc et ~/.yeelight.sh)
$ProfileDir = Split-Path -Path $PROFILE -Parent
if (-not (Test-Path $ProfileDir)) { New-Item -ItemType Directory -Path $ProfileDir | Out-Null }

$YEE_SCRIPT = Join-Path -Path $ProfileDir -ChildPath "yeelight.ps1"
$PROFILE_FILE = $PROFILE

Write-Host "`nCreation de $YEE_SCRIPT..."

# 2. Creer le contenu du script de controle Yeelight
$scriptContent = @"
# ==========================================
# CONTRoLE YEELIGHT (IP: $IP_INPUT)
# ==========================================
`$global:YEE_IP = "$IP_INPUT"

# 1. Fonction utilitaire invisible (Sans netcat, en .NET)
function _yee_send {
    param([string]`$payload)
    try {
        `$client = New-Object System.Net.Sockets.TcpClient
        # Timeout de 1s pour eviter que le terminal ne bloque
        `$result = `$client.BeginConnect(`$global:YEE_IP, 55443, `$null, `$null)
        `$success = `$result.AsyncWaitHandle.WaitOne(1000, `$false)
        
        if (`$success) {
            `$client.EndConnect(`$result)
            `$stream = `$client.GetStream()
            `$bytes = [System.Text.Encoding]::ASCII.GetBytes(`$payload + "`r`n")
            
            # Envoi avec double execution et delai de 500ms
            `$stream.Write(`$bytes, 0, `$bytes.Length)
            Start-Sleep -Milliseconds 500
            `$stream.Write(`$bytes, 0, `$bytes.Length)
            
            `$client.Close()
        }
    } catch {}
}

# 2. Fonction utilitaire pour traduire les noms de couleurs en decimal
function _yee_get_color {
    param([string]`$colorName)
    switch (`$colorName.ToLower()) {
        'white'  { return "16777215" }
        'red'    { return "16711680" }
        'green'  { return "65280" }
        'blue'   { return "255" }
        'yellow' { return "16776960" }
        'purple' { return "8388736" }
        'orange' { return "16753920" }
        default  { return "" }
    }
}

# --- Allumer / eteindre ---
function yee-on { _yee_send '{"id":1,"method":"set_power","params":["on", "smooth", 500]}' }
function yee-bg-on { _yee_send '{"id":1,"method":"bg_set_power","params":["on", "smooth", 500]}' }
function yee-bg-off { _yee_send '{"id":1,"method":"bg_set_power","params":["off", "smooth", 500]}' }

function yee-front-off { 
    _yee_send '{"id":1,"method":"set_power","params":["off", "smooth", 500]}'
    _yee_send '{"id":1,"method":"bg_set_power","params":["on", "smooth", 500]}'
}

function yee-off {
    _yee_send '{"id":1,"method":"set_power","params":["off", "smooth", 500]}'
    _yee_send '{"id":1,"method":"bg_set_power","params":["off", "smooth", 500]}'
}

# --- Luminosite (1 a 100) ---
function yee-bright {
    param(`$val)
    if ([string]::IsNullOrEmpty(`$val)) { Write-Host "Erreur: Precise un % (ex: yee-bright 50)"; return }
    _yee_send '{"id":1,"method":"set_bright","params":[' + `$val + ', "smooth", 500]}'
}

function yee-bg-bright {
    param(`$val)
    if ([string]::IsNullOrEmpty(`$val)) { Write-Host "Erreur: Precise un % (ex: yee-bg-bright 50)"; return }
    _yee_send '{"id":1,"method":"bg_set_bright","params":[' + `$val + ', "smooth", 500]}'
}

# --- Temperature Lampe principale (Kelvin ou Mots-cles) ---
function yee-temp {
    param(`$val)
    `$ct_val = `$val
    switch (`$val.ToLower()) {
        {`$_ -in 'chaud','warm'}  { `$ct_val = 2700 }
        {`$_ -in 'neutre','mid'}  { `$ct_val = 4000 }
        {`$_ -in 'froid','cold'}  { `$ct_val = 6500 }
    }

    if (`$ct_val -notmatch '^\d+`$') {
        Write-Host "Usage 1 : yee-temp <chaud|neutre|froid>"
        Write-Host "Usage 2 : yee-temp <valeur en Kelvin> (ex: 2700 a 6500)"
        return
    }
    _yee_send '{"id":1,"method":"set_ct_abx","params":[' + `$ct_val + ', "smooth", 500]}'
}

# --- Couleurs Background (Nom ou RGB) ---
function yee-bg-color {
    `$dec_val = ""
    if (`$args.Count -eq 1) {
        `$dec_val = _yee_get_color `$args[0]
        if ([string]::IsNullOrEmpty(`$dec_val)) { Write-Host "Couleur inconnue."; return }
    } elseif (`$args.Count -eq 3) {
        `$dec_val = ([int]`$args[0] -shl 16) -bor ([int]`$args[1] -shl 8) -bor [int]`$args[2]
    } else {
        Write-Host "Usage 1 : yee-bg-color <white|red|green|blue|yellow|purple|orange>"
        Write-Host "Usage 2 : yee-bg-color <R> <G> <B> (ex: yee-bg-color 255 0 0)"
        return
    }
    _yee_send '{"id":1,"method":"bg_set_rgb","params":[' + `$dec_val + ', "smooth", 500]}'
}

# --- Menu d'aide ---
function yee-help {
    Write-Host "`n=========================================="
    Write-Host "   CONTRoLE YEELIGHT (IP: `$global:YEE_IP)"
    Write-Host "==========================================`n"
    Write-Host "LAMPE PRINCIPALE (Avant)"
    Write-Host "  yee-on            : Allumer la lampe"
    Write-Host "  yee-off           : eteindre la lampe (peut impacter le BG)"
    Write-Host "  yee-front-off     : eteindre l'avant ET garder le BG allume"
    Write-Host "  yee-bright <%>    : Regler la luminosite (1-100)"
    Write-Host "  yee-temp <valeur> : Regler la temperature (chaud, neutre, froid, ou 2700-6500)`n"
    Write-Host "BACKGROUND (Arriere / Ambilight)"
    Write-Host "  yee-bg-on         : Allumer"
    Write-Host "  yee-bg-off        : eteindre"
    Write-Host "  yee-bg-bright <%> : Regler la luminosite (1-100)"
    Write-Host "  yee-bg-color <c>  : Changer la couleur (white, red, green... ou RGB)`n"
}
"@

$scriptContent | Out-File -FilePath $YEE_SCRIPT -Encoding UTF8

# 3. Verifier et mettre a jour le profil PowerShell (equivalent de .bashrc)
Write-Host "Verification de $PROFILE_FILE..."
if (!(Test-Path $PROFILE_FILE)) {
    New-Item -ItemType File -Path $PROFILE_FILE -Force | Out-Null
}

$profileContent = Get-Content $PROFILE_FILE -Raw
if ($profileContent -match "yeelight.ps1") {
    Write-Host "  Le lien dans le profil PowerShell est deja present."
} else {
    $importCommand = "`n# Charger les scripts personnalises Yeelight`nif (Test-Path `"$YEE_SCRIPT`") { . `"$YEE_SCRIPT`" }`n"
    Add-Content -Path $PROFILE_FILE -Value $importCommand -Encoding UTF8
    Write-Host "  Lien ajoute au profil PowerShell."
}

Write-Host "`n=========================================="
Write-Host "Installation terminee avec succes !"
Write-Host "Tapez la commande suivante pour activer :"
Write-Host "   . `$PROFILE"
Write-Host "=========================================="
