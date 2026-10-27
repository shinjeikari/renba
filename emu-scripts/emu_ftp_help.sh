#!/system/bin/sh
# Telas locais da TV Box: "Colocar jogos pelo computador", "Capas dos jogos" (progresso) e "Reiniciar". Atendidas so dentro da box
# (127.0.0.1:8099) pelo servico emu_help:  nc -s 127.0.0.1 -p 8099 -L sh /system/bin/emu_ftp_help.sh
# Os atalhos da aba Sistema abrem http://127.0.0.1:8099/<rota> no TV Bro. Rotas:
#   /          liga o servidor FTP (Primitive FTPd) e mostra IP, usuario, senha e o passo a passo
#   /done      desliga o FTP, aplica fundos e baixa capas em segundo plano, e abre /capas
#   /capa-manual  como colocar a capa a mao (hacks/homebrew)     /capas     progresso do download de capas (atualiza sozinha)      /baixar  baixa o que falta agora     /retentar  tenta de novo as nao achadas
#   /voltar    volta ao Pegasus: reabre so se houve novidade (chamada sozinha pela tela de capas ao terminar)
#   /menu      reabre o Pegasus de qualquer jeito (nao usada nas telas)
#   /reiniciar reinicia a TV Box na hora (sem pedir confirmacao)     /stop  so desliga o servidor FTP
export TMPDIR=/data/local/tmp
FTP=org.primftpd
PORT=2121
PEG=org.pegasus_frontend.android
PROG=/data/local/tmp/emu_covers.progress
LOCK=/data/local/tmp/emu_covers.lock
read -r REQ
RP=$(echo "$REQ" | cut -d' ' -f2)
# le os cabecalhos ate a linha em branco (fechar a conexao com dados nao lidos faz o navegador receber RST e cortar a pagina)
# e guarda os que mostram se o pedido veio de outra pagina da internet
CROSS=0
while read -r L; do
    [ ${#L} -le 1 ] && break
    case "$L" in
        [Oo]rigin:*|[Rr]eferer:*) case "$L" in *127.0.0.1:8099*) ;; *) CROSS=1;; esac;;
        [Ss]ec-[Ff]etch-[Ss]ite:*) case "$L" in *none*|*same-origin*) ;; *) CROSS=1;; esac;;
    esac
done
if [ $CROSS = 1 ]; then printf 'HTTP/1.0 403 Forbidden\r\nConnection: close\r\n\r\n'; exit 0; fi

ip_atual() {
    for i in wlan0 eth0; do
        v=$(ifconfig $i 2>/dev/null | sed -n 's/.*inet addr:\([0-9.]*\).*/\1/p')
        [ -n "$v" ] && { echo $v; return; }
    done
}
ligado() { awk '$4=="0A" && toupper($2) ~ /:0849$/ {f=1} END{exit !f}' /proc/net/tcp6 /proc/net/tcp 2>/dev/null; }
tem_cartao() { grep -q -E ' /storage/[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4} ' /proc/mounts; }
covers_rodando() { [ -f $LOCK ] && [ -d /proc/$(cat $LOCK 2>/dev/null) ]; }
cabecalho() { printf 'HTTP/1.0 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n'; }
redireciona() { printf 'HTTP/1.0 302 Found\r\nLocation: %s\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n' "$1"; }
# $1 = segundos para atualizar sozinha (opcional) e $2 = rota para onde ir (opcional)
estilo() {
    printf '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>TV Box</title>'
    [ -n "$1" ] && printf '<meta http-equiv="refresh" content="%s%s">' "$1" "${2:+;url=$2}"
    echo '<style>'
    echo 'body{background:#101820;color:#f2f2f2;font-family:sans-serif;font-size:27px;margin:0;padding:28px 44px;line-height:1.35}'
    echo 'h1{color:#ffb000;font-size:44px;margin:0 0 12px}h2{color:#7fc8ff;font-size:30px;margin:22px 0 6px}'
    echo 'code,.end{background:#1d2b38;color:#8fff8f;padding:3px 12px;border-radius:6px;font-family:monospace}'
    echo '.end{display:inline-block;font-size:34px;margin:6px 0}'
    echo '.ok{background:#12351f;border-left:8px solid #2fbf5f;padding:10px 18px}.erro{background:#3b1616;border-left:8px solid #e04040;padding:10px 18px}.aviso{background:#3a3010;border-left:8px solid #ffb000;padding:10px 18px;margin-top:14px}'
    echo 'table{border-collapse:collapse;margin:6px 0}td,th{border:1px solid #33475b;padding:4px 14px;text-align:left}th{background:#1d2b38}'
    echo 'a.bt{display:inline-block;background:#ffb000;color:#101820;text-decoration:none;font-weight:bold;padding:12px 26px;border-radius:8px;margin:8px 14px 8px 0}'
    echo 'a.b2{background:#33475b;color:#fff}a.b3{background:#e04040;color:#fff}small{color:#9fb0c0}'
    echo '.barra{background:#1d2b38;border-radius:10px;height:34px;width:100%;margin:12px 0}.barra div{background:#2fbf5f;height:34px;border-radius:10px}'
    echo '</style></head><body>'
}
# le uma chave do arquivo de progresso
pv() { sed -n "s/^$1=//p" $PROG 2>/dev/null | head -1; }

case "$RP" in
/stop)
    su -c "am start -n $FTP/.ui.StopServerAndExitActivity" >/dev/null 2>&1
    cabecalho; estilo
    echo '<h1>Servidor desligado</h1><p>Para enviar mais jogos, abra de novo o atalho <b>Colocar jogos</b> na aba Sistema.</p><p><small>Aperte o botao Voltar do controle para fechar esta tela.</small></p></body></html>'
    exit 0;;
/done|/baixar|/retentar)
    [ "$RP" = /done ] && su -c "am start -n $FTP/.ui.StopServerAndExitActivity" >/dev/null 2>&1
    if [ "$RP" = /retentar ]; then rm -f /storage/*/ROMs/*/media/.sem_capa 2>/dev/null; fi
    if ! covers_rodando; then
        printf 'estado=preparando
total=0
feitas=0
ok=0
semcapa=0
' > $PROG
        if [ "$RP" = /done ]; then
            # fundos dos jogos novos -> capas -> (no fim, o emu_covers chama emu_refresh: reabre o Pegasus so se houve novidade)
            ( EMU_SEM_REINICIO=1 setsid sh -c 'sh /system/bin/emu_firstboot.sh; sh /system/bin/emu_covers.sh' >/dev/null 2>&1 & )
        else
            ( setsid sh /system/bin/emu_covers.sh >/dev/null 2>&1 & )
        fi
        sleep 1
    fi
    redireciona /capas
    exit 0;;
/voltar)
    # so age quando nao ha download em andamento (uma aba antiga de "concluido" nao pode reabrir o menu no meio de um download)
    E=$(pv estado)
    if covers_rodando || { [ "$E" = preparando ] && [ -n "$(find $PROG -mmin -2 2>/dev/null)" ]; }; then redireciona /capas; exit 0; fi
    ( setsid sh -c 'sleep 1; sh /system/bin/emu_refresh.sh' >/dev/null 2>&1 & )
    cabecalho; estilo
    echo '<h1>Voltando ao menu...</h1></body></html>'
    exit 0;;
/menu)
    ( setsid sh -c "sleep 2; sh /system/bin/emu_refresh.sh forcar" >/dev/null 2>&1 & )
    cabecalho; estilo
    echo '<h1>Abrindo o menu...</h1><p>Em instantes o menu dos jogos aparece, ja com os jogos, capas e fundos novos.</p></body></html>'
    exit 0;;
/reiniciar)
    ( setsid sh -c 'sleep 3; svc power reboot || reboot' >/dev/null 2>&1 & )
    redireciona /reiniciando
    exit 0;;
/reiniciando)
    cabecalho; estilo
    echo '<h1>Reiniciando...</h1><p>Aguarde. A TV Box volta sozinha em cerca de 1 minuto. Se as capas ainda estavam sendo baixadas, o download continua de onde parou.</p></body></html>'
    exit 0;;
/capa-manual)
    cabecalho; estilo
    echo '<h1>Capa feita a mao</h1>'
    echo '<p>Hacks, traducoes e jogos de autores independentes <b>nao tem capa no banco online</b>: a TV Box nao consegue baixar. Voce coloca a imagem:</p>'
    echo '<h2>Jogos que ficaram sem capa</h2>'
    N=0
    for L in /storage/*/ROMs/*/media/.sem_capa; do
        [ -f "$L" ] || continue
        SYS=${L%/media/.sem_capa}; SYS=${SYS##*/}
        while IFS= read -r J; do
            [ -n "$J" ] || continue
            echo "<p><code>$SYS</code> &nbsp; <b>$J</b></p>"; N=$((N+1))
        done < "$L"
    done
    [ $N -eq 0 ] && echo '<p>Nenhum no momento.</p>'
    echo '<h2>Passo a passo</h2>'
    echo '<p>1. Escolha uma imagem do jogo (PNG ou JPG) e renomeie para <code>boxFront.png</code> (ou <code>boxFront.jpg</code>).</p>'
    echo '<p>2. Na aba Sistema, abra <b>Colocar jogos</b> e entre no endereco mostrado no Explorador de Arquivos do computador.</p>'
    echo '<p>3. Abra a pasta do sistema, depois <code>media</code>, e crie uma pasta com <b>exatamente o nome do arquivo do jogo, sem a extensao</b> (o nome escrito acima em negrito).</p>'
    echo '<p>4. Coloque o <code>boxFront.png</code> dentro dessa pasta. Exemplo:</p>'
    echo '<p><code>atari2600/media/Pitfall Unlimited (Atarius Maximus) (Hack)/boxFront.png</code></p>'
    echo '<p>5. Volte para a TV Box e toque em <b>Terminei</b>. O menu atualiza sozinho e a capa aparece.</p>'
    echo '<p><small>Imagens de 300 a 600 pixels de altura ja ficam boas. Quanto menor o arquivo, mais rapido o menu abre.</small></p>'
    echo '<p><a class="bt" href="/">Colocar jogos agora</a> <a class="bt b2" href="/voltar">Voltar ao menu</a></p>'
    echo '</body></html>'
    exit 0;;
/capas)
    E=$(pv estado); T=$(pv total); F=$(pv feitas); O=$(pv ok); S=$(pv semcapa)
    T=${T:-0}; F=${F:-0}; O=${O:-0}; S=${S:-0}
    PC=0; [ "$T" -gt 0 ] && PC=$((F*100/T))
    # sem arquivo de progresso: se o script esta rodando, ainda esta preparando; senao, nada em andamento
    # com progresso "em andamento" mas sem o script rodando (box reiniciada no meio): download interrompido
    R=""
    if covers_rodando; then R=3; [ -z "$E" ] && E=preparando
    else
        [ -z "$E" ] && E=nada
        if [ "$E" = preparando ] && [ -n "$(find $PROG -mmin -2 2>/dev/null)" ]; then R=3
        else case "$E" in baixando|rede|cartao|preparando) E=interrompido;; esac; fi
    fi
    cabecalho; estilo $R /capas
    echo '<h1>Capas dos jogos</h1>'
    case "$E" in
    preparando|cartao) echo '<div class="aviso"><b>Preparando...</b> procurando os jogos no cartao SD.</div>';;
    rede) echo "<div class=\"aviso\"><b>Aguardando a internet...</b> $T jogo(s) sem capa. As capas sao baixadas da internet; confira se a TV Box esta conectada.</div>";;
    baixando)
        echo "<div class=\"aviso\"><b>Midia pendente: baixando capas.</b> $F de $T jogos verificados ($PC%).</div>"
        echo "<div class=\"barra\"><div style=\"width:${PC}%\"></div></div>"
        echo "<p>Capas baixadas: <b>$O</b> &nbsp; Sem capa online: <b>$S</b></p>"
        echo '<p><small>Pode demorar varios minutos se voce colocou muitos jogos. Esta tela atualiza sozinha e, quando termina, o menu atualiza sozinho.</small></p>';;
    fim)
        if [ "$T" -eq 0 ]; then echo '<div class="ok"><b>Tudo em dia.</b> Todos os jogos ja tem capa (ou ja foram verificados).</div>'
        else echo "<div class=\"ok\"><b>Concluido.</b> $O capa(s) baixada(s)."; [ "$S" -gt 0 ] && echo " $S jogo(s) sem capa no banco online."; echo '</div>'; fi
        if [ "$S" -gt 0 ]; then
            echo '<p>Hacks, traducoes e jogos independentes nao tem capa no banco online: essas capas precisam ser colocadas a mao.</p>'
            echo '<p><a class="bt" href="/capa-manual">Como colocar a capa a mao</a> <a class="bt b2" href="/voltar">Voltar ao menu</a></p>'
        else
            echo '<p>Voltando ao menu...</p>'
            echo '<meta http-equiv="refresh" content="3;url=/voltar">'
        fi;;
    interrompido) echo "<div class=\"aviso\"><b>Download interrompido.</b> $F de $T jogos foram verificados antes de parar.</div><p><a class=\"bt\" href=\"/baixar\">Continuar de onde parou</a></p>";;
    sem_cartao) echo '<div class="erro"><b>Nao ha cartao SD na TV Box.</b> Coloque um cartao SD (FAT32) na TV Box.</div>';;
    sem_rede) echo '<div class="erro"><b>Sem internet.</b> A TV Box nao conseguiu acessar o site das capas. Conecte o Wi-Fi/cabo e tente de novo.</div><p><a class="bt" href="/baixar">Tentar de novo</a></p>';;
    *) echo '<div class="ok"><b>Nenhum download em andamento.</b></div><p><a class="bt" href="/baixar">Verificar capas pendentes agora</a></p>';;
    esac
    echo '</body></html>'
    exit 0;;
/|/index.html|"")
    ;;
*)
    printf 'HTTP/1.0 404 Not Found\r\nConnection: close\r\n\r\n'
    exit 0;;
esac

IP=$(ip_atual)
PW=$(cat /data/local/tmp/ftp_pass 2>/dev/null)
su -c "am start -n $FTP/.ui.StartServerAndExitActivity" >/dev/null 2>&1
n=0; while [ $n -lt 8 ] && ! ligado; do sleep 1; n=$((n+1)); done

cabecalho; estilo
echo '<h1>Colocar jogos pelo computador</h1>'
if [ -z "$IP" ]; then
    echo '<div class="erro"><b>A TV Box nao esta conectada a nenhuma rede.</b> Conecte o Wi-Fi (ou o cabo de rede) e abra este atalho de novo.</div></body></html>'
    exit 0
fi
if ligado; then
    echo '<div class="ok"><b>Servidor ligado.</b> Siga os passos abaixo no seu computador.</div>'
else
    echo '<div class="erro"><b>Nao foi possivel ligar o servidor.</b> Feche esta tela e abra o atalho de novo. </div>'
fi
tem_cartao || echo '<div class="erro" style="margin-top:12px"><b>Nao ha cartao SD na TV Box.</b> Os jogos ficam no cartao SD; coloque um cartao FAT32 na TV Box antes de enviar jogos.</div>'
echo "<h2>1. No computador (Windows)</h2>"
echo "<p>Ligue o computador na <b>mesma rede</b> da TV Box (o mesmo Wi-Fi ou o mesmo roteador). Aperte as teclas <b>Windows + E</b> para abrir o Explorador de Arquivos.</p>"
echo "<h2>2. Digite este endereco na barra de enderecos e aperte Enter</h2>"
echo "<p><span class=\"end\">ftp://roms:$PW@$IP:$PORT</span></p>"
echo "<p><small>Se o Windows pedir login: usuario <b>roms</b>, senha <b>$PW</b>. Endereco: <b>$IP</b>, porta <b>$PORT</b>. Esse IP e o da TV Box agora; se ele mudar, abra este atalho de novo.</small></p>"
echo "<h2>3. Copie os jogos para a pasta do console</h2>"
echo "<p>Abra a pasta do console e arraste os jogos para dentro:</p>"
echo "<table><tr><th>Console</th><th>Pasta</th><th>Arquivos</th></tr>"
echo "<tr><td>NES</td><td>nes</td><td>.nes</td></tr>"
echo "<tr><td>Super Nintendo</td><td>snes</td><td>.sfc .smc</td></tr>"
echo "<tr><td>Game Boy / Color</td><td>gb</td><td>.gb .gbc</td></tr>"
echo "<tr><td>Game Boy Advance</td><td>gba</td><td>.gba</td></tr>"
echo "<tr><td>Mega Drive</td><td>megadrive</td><td>.md .gen</td></tr>"
echo "<tr><td>Master System</td><td>mastersystem</td><td>.sms</td></tr>"
echo "<tr><td>Atari 2600</td><td>atari2600</td><td>.a26 .bin</td></tr>"
echo "<tr><td>PlayStation</td><td>psx</td><td>.cue (com o .bin ao lado)</td></tr></table>"
echo "<p><small>Arquivos .zip nao aparecem na lista: descompacte antes. O nome do arquivo vira o nome do jogo e tambem serve para achar a capa.</small></p>"
echo "<h2>4. Quando terminar, volte aqui</h2>"
echo "<p><a class=\"bt\" href=\"/done\">Terminei: atualizar jogos e capas</a><a class=\"bt b2\" href=\"/stop\">So desligar o servidor</a></p>"
echo "<div class=\"aviso\"><b>Observacao sobre as capas:</b> elas sao baixadas da internet <b>depois</b> que voce toca em \"Terminei\". Com muitos jogos (200 ou mais) isso leva varios minutos; na tela <b>Capas dos jogos</b> (aba Sistema) voce acompanha quantas faltam. Quando termina, o menu atualiza sozinho.</div>"
echo "<p><small>Depois de enviar os jogos, toque em \"Terminei\": o servidor desliga e tudo se atualiza sozinho. Use so em rede de casa: a senha e exclusiva desta TV Box.</small></p>"
echo "</body></html>"
