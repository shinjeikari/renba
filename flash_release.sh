#!/bin/bash
# Grava a imagem RENBA na particao super da TV Box (Allwinner sun50iw9p1, "MXQ Pro 4K").
# Uso:  ./flash_release.sh SIM [serial_adb]      (Linux, macOS ou Git Bash; precisa de adb, xz, sha256sum)
# So grava se o super atual for IDENTICO ao firmware de fabrica testado (ou a imagem limpa v1.0 do mesmo autor).
# Grava apenas os blocos de blocks.txt (269 de 2048).
set -u
cd "$(dirname "$0")" || exit 1
[ "${1:-}" = "SIM" ] || { echo "ABORTADO: passe SIM como 1o argumento (leia o README antes)."; exit 1; }
SER="${2:-}"
STOCK=172e9203f1649f9d9c3fdc145141cffaee1e3294b4c200c078fdca2742298fb5
CLEAN=5e1fa9fe99fda13f632252634b391f57225953d5975a94aa9242d2fa864b4d8a
EMU=923e16f04599e4a74e822e45dcf010e9958ac91eaf5ebcbc6230ff022b710cde
DEV=/dev/block/by-name/super
export MSYS_NO_PATHCONV=1
A(){ if [ -n "$SER" ]; then adb -s "$SER" "$@"; else adb "$@"; fi; }
sum(){ sha256sum | cut -c1-64; }
[ -f renba_super.img ] || { echo "descompactando (2 GB)..."; xz -dk renba_super.img.xz || exit 1; }
[ "$(sum < renba_super.img)" = "$EMU" ] || { echo "ERRO: renba_super.img corrompido"; exit 2; }
A shell "readlink $DEV" </dev/null | grep -q nand0p4 || { echo "ERRO: by-name/super nao e nand0p4; esta box nao e compativel"; exit 3; }
A shell "id -u" </dev/null | grep -q '^0' || { echo "ERRO: adb sem root"; exit 3; }
PROG=.flash_progress   # blocos ja gravados e conferidos (permite retomar se o Wi-Fi/adb cair no meio)
BUILD=$(A shell "getprop ro.build.display.id" </dev/null | tr -d '\r')
if [ -f "$PROG" ] && [ "$(head -n 1 "$PROG")" = "$BUILD" ]; then
  echo "Retomando uma gravacao interrompida ($(($(wc -l < "$PROG")-1)) blocos ja gravados). Ao final a imagem inteira e conferida."
else
  echo "Lendo o super atual para conferir (2 GB, alguns minutos)..."
  CUR=$(A exec-out "dd if=$DEV bs=1048576 2>/dev/null" </dev/null | sum)
  echo "super atual: $CUR"
  if [ "$CUR" = "$EMU" ]; then echo "Ja esta com esta imagem. Nada a fazer."; exit 0; fi
  [ "$CUR" = "$STOCK" ] || [ "$CUR" = "$CLEAN" ] || { echo "ERRO: o firmware desta box NAO e o de fabrica testado (nem a imagem limpa v1.0). Nada foi gravado."; exit 4; }
  echo "$BUILD" > "$PROG"
fi
echo "Base confirmada. Gravando blocos..."
retry(){ # tenta de novo (reconectando o adb) se a rede cair
  local i; for i in 1 2 3 4 5 6; do "$@" && return 0; echo "  (falha de conexao, tentativa $i de 6; reconectando...)"; [ -n "$SER" ] && adb connect "$SER" >/dev/null 2>&1; sleep 5; done; return 1
}
for n in $(cat blocks.txt); do
  grep -qx "$n" "$PROG" && continue
  dd if=renba_super.img of=c.bin bs=1048576 skip=$n count=1 status=none
  retry A push c.bin /data/local/tmp/c.bin </dev/null >/dev/null || { echo "ERRO push $n. Rode o script de novo para retomar; NAO reinicie."; exit 5; }
  retry A shell "dd if=/data/local/tmp/c.bin of=$DEV bs=1048576 seek=$n count=1 conv=notrunc 2>/dev/null; sync" </dev/null || { echo "ERRO gravacao $n. Rode de novo para retomar; NAO reinicie."; exit 5; }
  W=$(A exec-out "dd if=$DEV bs=1048576 skip=$n count=1 2>/dev/null" </dev/null | sum)
  [ "$W" = "$(sum < c.bin)" ] && { echo "bloco $n ok"; echo "$n" >> "$PROG"; } || { echo "ERRO verificacao do bloco $n. NAO reinicie; rode de novo ou veja o README (restauracao)."; exit 6; }
done
rm -f c.bin; A shell "rm -f /data/local/tmp/c.bin; sync" </dev/null
echo "Conferindo imagem inteira..."
END=$(A exec-out "dd if=$DEV bs=1048576 2>/dev/null" </dev/null | sum)
[ "$END" = "$EMU" ] && { rm -f "$PROG"; echo "TUDO OK. Reinicie: adb reboot"; } || { echo "ERRO: hash final diferente. NAO reinicie."; exit 7; }
