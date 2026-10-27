#!/system/bin/sh
# Atualiza o menu (Pegasus) SO se houve novidade nos jogos/capas/fundos do cartao SD; sem novidade, nao reinicia nada.
#   emu_refresh.sh           compara a "assinatura" dos arquivos de <cartao>/ROMs com a da ultima vez que o Pegasus abriu:
#                            mudou -> reabre o Pegasus (leva ~5 s; NAO reinicia a TV Box); igual -> so volta ao Pegasus se a tela atual
#                            for a pagina do TV Bro ("Capas dos jogos"/"Colocar jogos"). Se tem jogo rodando (RetroArch), nao interrompe.
#   emu_refresh.sh forcar    reabre o Pegasus de qualquer jeito (botao "Atualizar o menu agora")
#   emu_refresh.sh salvar    so grava a assinatura atual (usado pelo primeiro boot depois de abrir o Pegasus)
PEG=org.pegasus_frontend.android
SIGF=/data/local/tmp/emu_sig.last
SD=""
for d in /storage/*; do
    n=${d#/storage/}; case "$n" in emulated|self) continue;; esac
    grep -q " /storage/$n " /proc/mounts && [ -d $d/ROMs ] && SD=$d
done
SIG=none
# primeiro boot ainda rodando: ele mesmo grava a assinatura no fim
FBL=/data/local/tmp/emu_firstboot.lock
if [ "$1" != forcar ] && [ "$1" != salvar ] && [ -f $FBL ] && [ -d /proc/$(cat $FBL 2>/dev/null) ]; then echo "primeiro boot em andamento"; exit 0; fi
[ -z "$SD" ] && [ "$1" != forcar ] && { echo "sem cartao SD"; exit 0; }
[ -n "$SD" ] && SIG=$(find $SD/ROMs -type f ! -name '.sem_capa' ! -name '*.raw' ! -name '*.tmp' 2>/dev/null | sort | md5sum | cut -c1-32)
case "$1" in
salvar) echo "$SIG" > $SIGF; echo "assinatura salva"; exit 0;;
esac
FOCO=$(dumpsys window 2>/dev/null | grep mCurrentFocus)
case "$FOCO" in
*retroarch*) echo "jogo em andamento: nao interrompe"; exit 0;;
esac
reabre() {
    echo "$SIG" > $SIGF
    am force-stop $PEG
    am start -a android.intent.action.MAIN -c android.intent.category.HOME
}
if [ "$1" = forcar ] || [ "$SIG" != "$(cat $SIGF 2>/dev/null)" ]; then
    echo "novidade nos jogos/capas: reabrindo o Pegasus"
    reabre
else
    case "$FOCO" in
    *tvwebbrowser*) echo "sem novidade: voltando ao Pegasus"; am start -a android.intent.action.MAIN -c android.intent.category.HOME;;
    *) echo "sem novidade";;
    esac
fi
