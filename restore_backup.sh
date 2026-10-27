#!/bin/bash
# Devolve o super da box ao conteudo de um backup SEU (feito antes de gravar). Regrava so os blocos de 1 MiB que diferem.
# Uso: ./restore_backup.sh SIM meu_super_backup.img [serial_adb]
set -u
[ "${1:-}" = "SIM" ] || { echo "ABORTADO: passe SIM como 1o argumento."; exit 1; }
BK="${2:-}"; SER="${3:-}"; DEV=/dev/block/by-name/super
[ -f "$BK" ] && [ "$(stat -c %s "$BK")" = 2147483648 ] || { echo "ERRO: backup ausente ou com tamanho diferente de 2147483648"; exit 2; }
export MSYS_NO_PATHCONV=1
A(){ if [ -n "$SER" ]; then adb -s "$SER" "$@"; else adb "$@"; fi; }
sum(){ sha256sum | cut -c1-64; }
A shell "readlink $DEV" </dev/null | grep -q nand0p4 || { echo "ERRO: super != nand0p4"; exit 3; }
A shell "id -u" </dev/null | grep -q '^0' || { echo "ERRO: adb sem root"; exit 3; }
n=0; while [ $n -lt 2048 ]; do
  r=$(A exec-out "dd if=$DEV bs=1048576 skip=$n count=1 2>/dev/null" </dev/null | sum)
  dd if="$BK" of=rc.bin bs=1048576 skip=$n count=1 status=none
  if [ "$r" != "$(sum < rc.bin)" ]; then
    A push rc.bin /data/local/tmp/c.bin </dev/null >/dev/null || { echo "ERRO push $n"; exit 4; }
    A shell "dd if=/data/local/tmp/c.bin of=$DEV bs=1048576 seek=$n count=1 conv=notrunc 2>/dev/null; sync" </dev/null
    w=$(A exec-out "dd if=$DEV bs=1048576 skip=$n count=1 2>/dev/null" </dev/null | sum)
    [ "$w" = "$(sum < rc.bin)" ] && echo "bloco $n restaurado" || { echo "ERRO verificacao do bloco $n"; exit 5; }
  fi
  n=$((n+1))
done
rm -f rc.bin; A shell "rm -f /data/local/tmp/c.bin; sync" </dev/null
echo "RESTAURADO. Reinicie: adb reboot"
