#!/system/bin/sh
# Imagem "emu". Roda em TODO boot (rc: on property:sys.boot_completed=1).
#  1) Primeiro boot (flag /data/local/tmp/emu_done): instala Pegasus + RetroArch, copia os nucleos, define o Pegasus como tela inicial.
#  2) Todo boot: se ha cartao SD, usa-o como unico repositorio de conteudo: ROMs, capas, config/saves/estados do RetroArch.
#     A memoria interna da box fica so com o sistema (apps, nucleos). Sem cartao, so a aba "Sistema" aparece no Pegasus.
# Log: /data/local/tmp/emu_firstboot.log. Desativar: criar /data/local/tmp/no_emu. Repetir a instalacao: apagar /data/local/tmp/emu_done.
E=${EMU_DIR:-/system/etc/emu}
FLAG=/data/local/tmp/emu_done
LOG=/data/local/tmp/emu_firstboot.log
PEG=org.pegasus_frontend.android
RA=com.retroarch.ra32
C=/storage/emulated/0/Android/data/$PEG/files/pegasus-frontend
[ -f /data/local/tmp/no_emu ] && exit 0
main() {
echo "inicio: $(date)"
echo $$ > /data/local/tmp/emu_firstboot.lock
trap 'rm -f /data/local/tmp/emu_firstboot.lock' EXIT

# espera o armazenamento compartilhado (/storage/emulated/0) ficar disponivel
i=0
while [ ! -d /storage/emulated/0/Android ] && [ $i -lt 90 ]; do sleep 2; i=$((i+1)); done
[ -d /storage/emulated/0/Android ] || { echo "ERRO: /storage/emulated/0 indisponivel"; exit 1; }

if [ ! -f $FLAG ]; then
    for p in pegasus retroarch; do
        cp "$E/$p.apk" /data/local/tmp/emu_$p.apk || { echo "ERRO copia $p"; exit 1; }
        echo "instalando $p"
        cmd package install -r /data/local/tmp/emu_$p.apk
        rm -f /data/local/tmp/emu_$p.apk
    done

    # nucleos libretro: o linker do app so aceita bibliotecas em /data, entao copia (como root, via su) para a pasta do RetroArch
    D=/data/data/$RA
    n=0
    while [ $n -lt 30 ]; do su -c id 2>/dev/null | grep -q uid=0 && break; sleep 2; n=$((n+1)); done
    RUID=$(stat -c %u $D)
    su -c "mkdir -p $D/cores; cp $E/cores/*.so $D/cores/; chown -R $RUID:$RUID $D/cores; chmod 755 $D/cores $D/cores/*.so; restorecon -R $D/cores"
    echo "nucleos copiados (uid $RUID)"

    for a in $PEG $RA; do
        for perm in READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE; do
            pm grant $a android.permission.$perm
        done
    done

    # o Pegasus cria sua pasta de configuracao na primeira execucao
    am start -n $PEG/.MainActivity
    sleep 10
    am force-stop $PEG
    mkdir -p $C
    cmd package set-home-activity $PEG/.MainActivity
    touch $FLAG
fi

# nucleos acrescentados em imagens novas (a instalacao acima so roda uma vez): copia os que faltam na pasta do RetroArch
D=/data/data/$RA
n=0
while [ $n -lt 30 ]; do su -c id 2>/dev/null | grep -q uid=0 && break; sleep 2; n=$((n+1)); done
have=$(su -c "ls $D/cores" 2>/dev/null)
need=0
for f in $E/cores/*.so; do echo "$have" | grep -qx "${f##*/}" || need=1; done
if [ $need = 1 ] && [ -d $D ]; then
    RUID=$(stat -c %u $D)
    su -c "mkdir -p $D/cores; cp $E/cores/*.so $D/cores/; chown -R $RUID:$RUID $D/cores; chmod 755 $D/cores $D/cores/*.so; restorecon -R $D/cores"
    echo "nucleos novos copiados"
fi

# --- cartao SD (volume removivel em /storage/<ID>, ex.: 1E04-3C28) ---
SD=""
i=0
while [ -z "$SD" ] && [ $i -lt 45 ]; do
    for d in /storage/*; do
        n=${d#/storage/}
        case "$n" in emulated|self) continue;; esac
        grep -q " /storage/$n " /proc/mounts && SD=$d
    done
    [ -z "$SD" ] && sleep 2
    i=$((i+1))
done
mkdir -p $C
# aba Android propria (com fundo): desliga a lista nativa de apps do Pegasus, que nao aceita fundo. So grava se a chave nao existe (respeita a escolha do usuario)
grep -q 'providers.androidapps.enabled' $C/settings.txt 2>/dev/null || printf 'providers.androidapps.enabled: false\n' >> $C/settings.txt
if [ -n "$SD" ]; then
    echo "cartao SD: $SD"
    # primeira vez neste cartao: grava as ROMs de teste, capas e colecoes (so uma vez; depois o cartao e do usuario)
    if [ ! -f $SD/ROMs/.emu_seeded ]; then
        mkdir -p $SD/ROMs
        for x in nes gb gba snes megadrive psx metadata.pegasus.txt; do
            [ -e $SD/ROMs/$x ] || cp -r $E/ROMs/$x $SD/ROMs/
        done
        touch $SD/ROMs/.emu_seeded
    fi
    # sistemas acrescentados depois (cartoes que ja existiam): grava a pasta com a ROM de teste e a colecao no metadata, uma vez por sistema
    for x in mastersystem atari2600; do
        [ -f $SD/ROMs/.emu_seeded_$x ] && continue
        [ -d $SD/ROMs/$x ] || cp -r $E/ROMs/$x $SD/ROMs/
        grep -q "^shortname: $x\$" $SD/ROMs/metadata.pegasus.txt 2>/dev/null || { printf '\n' >> $SD/ROMs/metadata.pegasus.txt; cat $E/meta_extra/$x.txt >> $SD/ROMs/metadata.pegasus.txt; }
        touch $SD/ROMs/.emu_seeded_$x
    done
    # RetroArch: so pode gravar na propria pasta Android/data dentro do cartao (Android 10). Config, saves, estados e capturas ficam la.
    F=$SD/Android/data/$RA/files
    mkdir -p $F/saves $F/states $F/screenshots
    [ -f $F/retroarch.cfg ] || printf 'input_android_physical_keyboard = "sunxi-ir-uinput"\nquit_press_twice = "true"\ninput_enable_hotkey_btn = "109"\ninput_exit_emulator_btn = "108"\ninput_save_state_btn = "103"\ninput_load_state_btn = "102"\ninput_state_slot_increase_btn = "h0right"\ninput_state_slot_decrease_btn = "h0left"\ninput_player1_analog_dpad_mode = "1"\ninput_player2_analog_dpad_mode = "1"\njoypad_autoconfig_dir = "%s/autoconfig"\nsavefile_directory = "%s/saves"\nsavestate_directory = "%s/states"\nscreenshot_directory = "%s/screenshots"\nsystem_directory = "%s/ROMs/bios"\n' $F $F $F $F $SD > $F/retroarch.cfg
    # perfis de controle (Xbox 360/xpad do dongle 8BitDo, DualShock 4): sem eles o RetroArch avisa "nao configurado"
    mkdir -p $F/autoconfig
    cp -n $E/autoconfig/*.cfg $F/autoconfig/
    # fundo do console atras de cada jogo: o tema do Pegasus so usa fundo por jogo (media/<rom>/background.jpg), entao copia o do sistema
    # para os jogos que ainda nao tem um (nao sobrescreve; para usar um fundo seu, ponha o arquivo na pasta do jogo)
    for linha in "nes@nes" "gb@gb gbc" "gba@gba" "snes@sfc smc" "megadrive@md gen" "psx@cue" "mastersystem@sms" "atari2600@a26 bin"; do
        dir=${linha%%@*}; exts=${linha#*@}
        [ -d $SD/ROMs/$dir ] && [ -f $E/backgrounds/$dir.jpg ] || continue
        for ext in $exts; do
            for f in $SD/ROMs/$dir/*.$ext; do
                [ -f "$f" ] || continue
                b=${f##*/}; b=${b%.*}; m=$SD/ROMs/$dir/media/$b
                [ -f "$m/background.jpg" ] || [ -f "$m/background.png" ] && continue
                mkdir -p "$m" && cp $E/backgrounds/$dir.jpg "$m/background.jpg"
            done
        done
    done
    printf '%s/ROMs\n%s/ROMs/sistema\n%s/ROMs/android\n' $SD $E $E > /data/local/tmp/game_dirs.new
else
    echo "sem cartao SD: so a aba Sistema"
    printf '%s/ROMs/sistema\n%s/ROMs/android\n' $E $E > /data/local/tmp/game_dirs.new
fi

# --- servidor FTP para enviar jogos pelo computador (atalho "Colocar jogos" na aba Sistema; pagina em emu_ftp_help.sh) ---
# Instala o Primitive FTPd, cria uma senha aleatoria desta box (hash SHA-512 com o sal do app) e aponta a pasta raiz para <cartao>/ROMs.
# Modo "super usuario" do app: o Android nao deixa apps comuns gravarem no cartao, mas o su desta imagem deixa.
FP=org.primftpd
if [ -f $E/primftpd.apk ] && [ -z "$(pm path $FP 2>/dev/null)" ]; then
    cp $E/primftpd.apk /data/local/tmp/emu_primftpd.apk && cmd package install -r /data/local/tmp/emu_primftpd.apk
    rm -f /data/local/tmp/emu_primftpd.apk
    echo "primftpd instalado"
fi
if [ -n "$(pm path $FP 2>/dev/null)" ]; then
    [ -s /data/local/tmp/ftp_pass ] || { tr -dc 'a-hj-km-np-z2-9' </dev/urandom | head -c 8 > /data/local/tmp/ftp_pass; rm -f /data/local/tmp/ftp_prefs_ok; }
    PW=$(cat /data/local/tmp/ftp_pass)
    PF=/data/data/$FP/shared_prefs/org.primftpd_preferences.xml
    FU=$(stat -c %u /data/data/$FP)
    FSD=/storage/emulated/0/ROMs
    [ -n "$SD" ] && FSD=$SD/ROMs
    if [ ! -f /data/local/tmp/ftp_prefs_ok ]; then
        HASH=$(printf '%sH\302\247R&q}9' "$PW" | sha512sum | cut -d' ' -f1 | xxd -r -p | base64 -w 0)
        printf "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n    <string name=\"storageTypePref\">2</string>\n    <string name=\"whichServerToStartPref\">1</string>\n    <string name=\"portPref\">2121</string>\n    <string name=\"userNamePref\">roms</string>\n    <string name=\"passwordPref\">%s</string>\n    <boolean name=\"anonymousLoginPref\" value=\"false\" />\n    <string name=\"startDirPref\">%s</string>\n    <string name=\"ftpPassivePortsPref\">5678-5700</string>\n</map>\n" "$HASH" "$FSD" > /data/local/tmp/ftp_prefs.xml
        su -c "mkdir -p /data/data/$FP/shared_prefs; cp /data/local/tmp/ftp_prefs.xml $PF; chown $FU:$FU /data/data/$FP/shared_prefs $PF; chmod 660 $PF; restorecon -R /data/data/$FP/shared_prefs"
        rm -f /data/local/tmp/ftp_prefs.xml
        touch /data/local/tmp/ftp_prefs_ok
        echo "ftp: configuracao criada (pasta $FSD)"
    else
        # o ID do cartao muda de cartao para cartao: so atualiza a pasta raiz (senha e demais opcoes do usuario ficam como estao)
        su -c "sed -i 's#<string name=\"startDirPref\">[^<]*<#<string name=\"startDirPref\">$FSD<#' $PF"
        # varias portas de dados: o Explorador do Windows envia varios arquivos ao mesmo tempo (com uma porta so, a copia trava)
        su -c "grep -q ftpPassivePortsPref $PF || { sed -i '/<\/map>/d' $PF; cat $E/ftp_passive.line >> $PF; echo '</map>' >> $PF; }"
    fi
fi
if ! cmp -s /data/local/tmp/game_dirs.new $C/game_dirs.txt; then
    cp /data/local/tmp/game_dirs.new $C/game_dirs.txt
    # no fluxo "Terminei" (EMU_SEM_REINICIO=1) quem decide reabrir o Pegasus e o emu_refresh.sh, so se houve novidade
    if [ -z "$EMU_SEM_REINICIO" ]; then
        am force-stop $PEG
        am start -a android.intent.action.MAIN -c android.intent.category.HOME
    fi
fi
rm -f /data/local/tmp/game_dirs.new
# o TV Bro recarrega as abas antigas ao abrir: apaga as das telas locais (uma aba velha de "reiniciar" reiniciaria a box sozinha)
TB=/data/data/com.phlox.tvwebbrowser/databases/main.db
su -c "[ -f $TB ] && sqlite3 $TB \"delete from tabs where url like 'http://127.0.0.1:8099/%' or url like 'file:///sdcard/emu%'; delete from history where url like 'http://127.0.0.1:8099/%';\""
# assinatura dos jogos/capas/fundos do cartao na hora em que o Pegasus abriu (base para "so reabre se houve novidade")
# (no fluxo "Terminei" NAO salva: o Pegasus ainda nao reabriu, e salvar aqui escondia os arquivos novos do emu_refresh.sh)
[ -z "$EMU_SEM_REINICIO" ] && sh /system/bin/emu_refresh.sh salvar
echo "fim: $(date)"
}
main >$LOG 2>&1
