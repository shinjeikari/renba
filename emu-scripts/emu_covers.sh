#!/system/bin/sh
# Baixa capas que faltam para os jogos do cartao SD (fonte: thumbnails.libretro.com, nomes No-Intro) e grava no formato do Pegasus:
#   <cartao>/ROMs/<sistema>/media/<nome da ROM sem extensao>/boxFront.png
# Roda uma vez por boot, em segundo plano (servico emu_covers), e quando o atalho "Colocar jogos" pede (/done). So baixa o que falta e
# nao repete tentativas que falharam (lista <cartao>/ROMs/<sistema>/media/.sem_capa; para tentar de novo, apague essa lista).
# Se a box reiniciar no meio, o proximo boot continua de onde parou (so o que ainda falta).
# Progresso (lido pela pagina "Capas dos jogos"): /data/local/tmp/emu_covers.progress. Log: /data/local/tmp/emu_covers.log
# Precisa de rede (Wi-Fi/cabo) e de cartao SD. Sem rede, sai sem fazer nada. No fim, se baixou capas e o Pegasus esta na tela, reabre o Pegasus.
LOG=/data/local/tmp/emu_covers.log
PROG=/data/local/tmp/emu_covers.progress
LOCK=/data/local/tmp/emu_covers.lock
HOST=thumbnails.libretro.com
[ -f /data/local/tmp/no_emu ] && exit 0
enc() { echo "$1" | sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's/#/%23/g' -e 's/\[/%5B/g' -e 's/\]/%5D/g'; }
safe() { echo "$1" | sed -e 's/[&*\/:`<>?\|]/_/g'; }
get() { # $1=sistema_libretro $2=pasta(Named_Boxarts...) $3=nome $4=destino. HTTP/1.0 cru via nc (o wget do busybox manda Host duplicado)
    path="/$(enc "$1")/$2/$(enc "$(safe "$3")").png"
    # ate 3 tentativas: o nc as vezes devolve a resposta cortada (o tamanho nao fecha com o Content-Length)
    for tent in 1 2 3; do
        rm -f "$4.tmp"
        printf 'GET %s HTTP/1.0\r\nHost: %s\r\nUser-Agent: emu-covers\r\nConnection: close\r\n\r\n' "$path" "$HOST" | nc -w 20 $IP 80 > "$4.raw" 2>/dev/null
        if head -1 "$4.raw" | grep -q ' 200 '; then
            cl=$(grep -a -m1 -i '^Content-Length:' "$4.raw" | tr -dc '0-9')
            [ -n "$cl" ] && [ "$cl" -gt 500 ] && tail -c "$cl" "$4.raw" > "$4.tmp"
            if [ -s "$4.tmp" ] && [ "$(head -c 4 "$4.tmp" | od -An -tx1 | tr -d ' ')" = "89504e47" ] && [ "$(wc -c < "$4.tmp")" -eq "$cl" ]; then
                rm -f "$4.raw"; mv "$4.tmp" "$4"; return 0
            fi
        fi
        head -1 "$4.raw" | grep -q ' 200 ' || break
    done
    rm -f "$4.raw" "$4.tmp"; return 1
}
# nomes fora do padrao No-Intro (ex.: "Combat (1977) (Atari) (4K)"): tenta o titulo puro com as regioes do libretro ("Combat (USA)")
tenta_regioes() { # $1=sistema $2=titulo $3=destino
    [ -n "$2" ] || return 1
    for r in "USA" "Europe" "World" "USA, Europe" "Japan"; do
        get "$1" Named_Boxarts "$2 ($r)" "$3" && return 0
    done
    return 1
}
# ultimo recurso: baixa a lista de nomes da pasta do sistema no servidor (uma vez por boot) e procura o jogo pelo titulo principal
# (ex.: "MegaMania (1982) (Activision)" -> "MegaMania - A Space Nightmare (USA)"); preferencia USA > World > Europe, sem hacks/betas
AWKP='function toks(s, arr,    n, i, w, k, a) {
    s = tolower(s); sub(/ ?[\(\[].*/, "", s); gsub(/[^a-z0-9]+/, " ", s)
    n = split(s, a, " "); k = 0
    for (i = 1; i <= n; i++) {
        w = a[i]
        if (w == "the" || w == "a" || w == "an" || w == "of" || w == "in" || w == "and" || w == "to") continue
        if (length(w) > 3) sub(/s$/, "", w)
        arr[++k] = w
    }
    return k
}
BEGIN { nb = toks(base, B); for (i = 1; i <= nb; i++) inb[B[i]] = 1 }
{
    n = toks($0, C); if (n == 0 || nb == 0) next
    delete inc; for (i = 1; i <= n; i++) inc[C[i]] = 1
    m = 0; for (i = 1; i <= nb; i++) if (B[i] in inc) m++
    if (m == nb && B[1] == C[1]) sc = 100 - (n - nb); else next
    rk = 3
    if ($0 ~ /\(USA/) rk = 0; else if ($0 ~ /\(World/) rk = 1; else if ($0 ~ /\(Europe/) rk = 2
    if ($0 ~ /\[/ || $0 ~ /\((Proto|Beta|Hack|Demo|Unl|Pirate)/) rk += 10
    t = sc * 100 - rk * 20 - length($0) / 10
    if (best == "" || t > bt) { best = $0; bt = t }
}
END { if (best != "") print best }'
indice() { # $1=sistema_libretro -> imprime o arquivo de indice (nada se nao conseguiu)
    ix=/data/local/tmp/emu_idx_$(echo "$1" | tr -dc 'A-Za-z0-9')
    if [ ! -s "$ix" ]; then
        for tent in 1 2 3; do
            printf 'GET /%s/Named_Boxarts/ HTTP/1.0\r\nHost: %s\r\nUser-Agent: emu-covers\r\nConnection: close\r\n\r\n' "$(enc "$1")" "$HOST" | nc -w 30 $IP 80 > "$ix.raw" 2>/dev/null
            if head -1 "$ix.raw" | grep -q ' 200 ' && tail -c 200 "$ix.raw" | grep -qi '</html>'; then
                grep -a -o 'href="[^"]*[.]png"' "$ix.raw" | sed -e 's/^href="//' -e 's/[.]png"$//' -e 's/%20/ /g' -e "s/%27/'/g" -e 's/%21/!/g' -e 's/%2C/,/g' -e 's/%28/(/g' -e 's/%29/)/g' -e 's/%5B/[/g' -e 's/%5D/]/g' -e 's/%23/#/g' -e 's/%2B/+/g' > "$ix"
                break
            fi
        done
        rm -f "$ix.raw"
    fi
    [ -s "$ix" ] && echo "$ix"
}
acha_por_titulo() { # $1=sistema $2=titulo $3=destino
    [ -n "$2" ] || return 1
    ix=$(indice "$1"); [ -n "$ix" ] || return 1
    nome=$(awk -v base="$2" "$AWKP" "$ix")
    [ -n "$nome" ] || return 1
    get "$1" Named_Boxarts "$nome" "$3"
}
# grava o progresso (arquivo pequeno, trocado de uma vez para a pagina nunca ler pela metade)
prog() { printf 'estado=%s\ntotal=%s\nfeitas=%s\nok=%s\nsemcapa=%s\n' "$1" "${total:-0}" "${feitas:-0}" "${ok:-0}" "${falta:-0}" > $PROG.tmp && mv $PROG.tmp $PROG; }
# pasta @ sistema na libretro-thumbnails @ extensoes
SISTEMAS='nes@Nintendo - Nintendo Entertainment System@nes
gb@Nintendo - Game Boy@gb
gb@Nintendo - Game Boy Color@gbc
gba@Nintendo - Game Boy Advance@gba
snes@Nintendo - Super Nintendo Entertainment System@sfc smc
megadrive@Sega - Mega Drive - Genesis@md gen
psx@Sony - PlayStation@cue
mastersystem@Sega - Master System - Mark III@sms
atari2600@Atari - 2600@a26 bin'
# varre os jogos sem capa; MODO=conta so conta, MODO=baixa baixa
varrer() {
    echo "$SISTEMAS" | while IFS= read -r linha; do
        dir=${linha%%@*}; r=${linha#*@}; sys=${r%%@*}; exts=${r#*@}
        [ -d $SD/ROMs/$dir ] || continue
        for ext in $exts; do
            for f in $SD/ROMs/$dir/*.$ext; do
                [ -f "$f" ] || continue
                b=${f##*/}; b=${b%.*}
                m=$SD/ROMs/$dir/media/$b
                [ -f "$m/boxFront.png" ] || [ -f "$m/boxFront.jpg" ] && continue
                L=$SD/ROMs/$dir/media/.sem_capa
                grep -qxF "$b" $L 2>/dev/null && continue
                echo "$dir@$sys@$b"
            done
        done
    done
}
main() {
echo "inicio: $(date)"
if [ -f $LOCK ] && [ -d /proc/$(cat $LOCK) ]; then echo "ja esta rodando"; exit 0; fi
echo $$ > $LOCK
trap 'rm -f $LOCK; sh /system/bin/emu_refresh.sh' EXIT
total=0; feitas=0; ok=0; falta=0
prog cartao
SD=""; i=0
while [ -z "$SD" ] && [ $i -lt 60 ]; do
    for d in /storage/*; do
        n=${d#/storage/}; case "$n" in emulated|self) continue;; esac
        grep -q " /storage/$n " /proc/mounts && [ -d $d/ROMs ] && SD=$d
    done
    [ -z "$SD" ] && sleep 3; i=$((i+1))
done
[ -n "$SD" ] || { echo "sem cartao SD"; prog sem_cartao; exit 0; }
# lista do que falta, antes de tudo: assim a pagina ja sabe o total
varrer > /data/local/tmp/emu_covers.lista
total=$(wc -l < /data/local/tmp/emu_covers.lista | tr -dc '0-9'); total=${total:-0}
echo "cartao $SD, sem capa: $total"
if [ "$total" -eq 0 ]; then prog fim; echo "nada a baixar"; rm -f /data/local/tmp/emu_covers.lista; exit 0; fi
prog rede
IP=""; i=0
while [ -z "$IP" ] && [ $i -lt 40 ]; do
    IP=$(ping -c1 -W3 $HOST 2>/dev/null | head -1 | sed -n 's/^PING [^ ]* (\([0-9.]*\)).*/\1/p')
    [ -z "$IP" ] && sleep 3; i=$((i+1))
done
[ -n "$IP" ] || { echo "sem rede (nao resolveu $HOST)"; prog sem_rede; rm -f /data/local/tmp/emu_covers.lista; exit 0; }
echo "servidor $IP"
rm -f /data/local/tmp/emu_idx_*
prog baixando
while IFS= read -r item; do
    dir=${item%%@*}; r=${item#*@}; sys=${r%%@*}; b=${r#*@}
    m=$SD/ROMs/$dir/media/$b
    L=$SD/ROMs/$dir/media/.sem_capa
    mkdir -p "$m"
    sem=${b%% \[*}
    base=$(echo "$b" | sed -e 's/ [(\[].*//')
    if get "$sys" Named_Boxarts "$b" "$m/boxFront.png" || get "$sys" Named_Boxarts "$sem" "$m/boxFront.png" \
       || get "$sys" Named_Titles "$b" "$m/boxFront.png" || get "$sys" Named_Snaps "$b" "$m/boxFront.png" \
       || tenta_regioes "$sys" "$base" "$m/boxFront.png" \
       || acha_por_titulo "$sys" "$base" "$m/boxFront.png"; then
        echo "ok: $dir/$b"; ok=$((ok+1))
    else
        echo "sem capa online: $dir/$b"; echo "$b" >> $L; falta=$((falta+1)); rmdir "$m" 2>/dev/null
    fi
    feitas=$((feitas+1)); prog baixando
done < /data/local/tmp/emu_covers.lista
rm -f /data/local/tmp/emu_covers.lista
prog fim
echo "baixadas: $ok, nao encontradas: $falta"
echo "fim: $(date)"
# ao sair (trap), emu_refresh.sh reabre o Pegasus SO se houve novidade (jogos, capas ou fundos); sem novidade, nao reinicia nada
}
main >$LOG 2>&1
