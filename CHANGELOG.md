# RENBA — histórico de versões (como a imagem foi construída)

Cada versão abaixo foi uma imagem de verdade, gravada numa única box (a do autor) e testada ao vivo, de 24 a 28/10/2026. Os números (`v1` … `v12n`) são os da construção; só a **v12n** é publicada. O que está marcado **"nunca gravada"** foi montado mas substituído antes de ir para a box.

## Ponto de partida
- **Imagem limpa v1.0** (outro projeto): firmware de fábrica sem adware, sem `/system/preinstall`, sem OTA, com TV Bro e Aurora Store, `ro.adb.secure=1`, swap em zram. A RENBA é construída em cima dela.

## Fase 1 — emuladores na box (v1–v7)
- **Teste dos emuladores** instalados em `/data`: Pegasus (alpha16) + RetroArch 32 bits + 7 núcleos (fceumm, gambatte, mgba, snes9x, genesis_plus_gx, picodrive, pcsx_rearmed). Cadeia Pegasus → RetroArch → jogo funcionando; todos os núcleos abriram um jogo.
- **Jogos de teste livres** escolhidos e conferidos por licença (NES, GB, GBA, SNES, Mega Drive, PS1).
- **v1:** primeira imagem: apps, núcleos e ROMs dentro de `/system/etc/emu`; um serviço de primeiro boot instala os apps, dá as permissões e define o Pegasus como tela inicial.
- **Descobertas:** com `/data` apagado e sem Wi‑Fi nem pendrive a box ficou sem acesso às Configurações; daí nasceu a **aba Sistema** (atalhos para Configurações, Wi‑Fi, Opções de desenvolvedor). Pendrive e leitor USB não foram reconhecidos em nenhuma porta (armazenamento USB não suportado). Bluetooth sem chip utilizável.
- **v2–v7:** controle remoto IR (4/6 trocam de aba), correções do primeiro boot, aba Sistema separada do restante.

## Fase 2 — tudo no cartão SD (v8–v10)
- **v8:** a memória interna guarda só o sistema; ROMs, capas, configuração, saves e estados do RetroArch ficam no cartão SD. Achado: o RetroArch só grava em `<cartão>/Android/data/com.retroarch.ra32/files/`; a imagem configura isso sozinha. O código do cartão muda de cartão para cartão e é detectado a cada boot.
- **v9:** decisão sobre o botão Voltar: volta a ser Voltar normal do Android; o botão 9 do remoto faz o papel de ESC/menu (no RetroArch, dois toques saem do jogo).
- **v10 (nunca gravada, substituída pela v11):** download automático de capas (libretro-thumbnails) via `nc` com HTTP cru, porque o `wget` da box não serve.

## Fase 3 — acabamento (v11–v12c)
- **v11:** capas automáticas, fundos por console (ilustrações públicas) e perfis de controle para evitar o aviso "controle não configurado". Controles testados: DualShock 4 por cabo e adaptadores 8BitDo.
- **v11 (pessoal):** fundos com fotos do autor e aba Sistema com tema Android.
- **v12:** aba **Android** própria (Aurora Store, TV Bro, RetroArch) e **save state** (Select+R1 salva, Select+L1 carrega, Select+direita/esquerda troca o slot).
- **v12b:** tela de boot **RENBA**.
- **v12c:** **Master System** (genesis_plus_gx) e **Atari 2600** (stella), com um jogo livre de cada. Gravada e conferida bloco a bloco.

## Fase 4 — facilidade de uso (v12d–v12n)
- **v12d:** o touchpad do DualShock 4/DualSense deixou de aparecer como ponteiro de mouse (`excluded-input-devices.xml`).
- **v12e–v12f:** atalho **Colocar jogos (pelo computador)**: servidor FTP com senha gerada no primeiro boot (Primitive FTPd), página com o endereço, tela **Capas dos jogos** com barra de progresso, atalho **Reiniciar a TV Box**.
- **v12g:** atualização "só se houve novidade": ao terminar de colocar jogos, o menu reabre sozinho só se algo mudou. Texto do fluxo sem falar em reiniciar nada.
- **v12h:** corrige a página "Colocar jogos" (scripts do Android não aceitam heredoc; a tela do FTP não é exportada e precisa de `su`).
- **v12i:** reinício **imediato** (sem pedir confirmação); faixa de portas passivas do FTP (5678–5700), porque o Explorador do Windows envia vários arquivos ao mesmo tempo e a porta única travava a cópia.
- **v12j:** o atalho Colocar jogos reiniciava a box sozinho (o TV Bro recarregava uma aba antiga de reiniciar). Correção: a rota redireciona e o boot apaga as abas e o histórico antigos do TV Bro.
- **v12k:** download de capas com **3 tentativas** (o `nc` às vezes devolve a resposta cortada) e busca tolerante (título sem etiquetas, regiões USA/Europe/World/Japan).
- **v12l:** busca de capas pelo **título principal**: se o nome exato não existe, baixa a lista de nomes do servidor e acha o jogo (ex.: `MegaMania (1982) (Activision)` → `MegaMania - A Space Nightmare (USA)`).
- **v12m:** página **"Como colocar a capa à mão"** para hacks, traduções e jogos independentes (lista os jogos sem capa e dá o passo a passo).
- **v12n (publicada):** o botão **Terminei** deixava de reabrir o Pegasus quando só havia capas colocadas à mão (o script de boot gravava a "assinatura" dos arquivos antes da comparação). Corrigido.

## Testes de fechamento (24–28/10/2026)
- Primeiro boot do zero **com** cartão SD e **sem** cartão (apagando dados pelo adb e por Configurações > Preferências do dispositivo > Redefinir).
- Restauração do firmware de fábrica com o `restore_backup.sh` da release, `check_compat.sh` (COMPATÍVEL) e gravação com o `flash_release.sh` (feitos com a build v12m).
- O Wi‑Fi caiu em todos os fluxos longos de gravação: por isso os scripts de gravação retomam sozinhos e refazem as tentativas.
- Capas: MegaMania, Smurfs e Montezuma's Revenge (PAL60) passaram a ser achadas; Pitfall II existe no servidor com arquivo vazio (sem capa real); Pitfall Unlimited (hack) e River Raid III não existem lá e precisam de capa à mão.
- Envio por FTP: 5 a 6 arquivos em paralelo pelo Explorador do Windows funcionam. A exclusão de arquivo pelo Explorador falhou uma vez e não foi reproduzida com outros dois clientes FTP (a exclusão funciona no servidor).

## O que nunca foi testado (resumo)
Outras boxes, outros firmwares ou lotes (só a build de fábrica descrita no README foi usada; testes de outros são bem-vindos); recuperação com a box sem boot (boot por cartão SD, FEL/PhoenixSuit, recovery de fábrica); Bluetooth; armazenamento USB; PS1 e jogos pesados sob 1 GB de RAM; `flash_release.sh` partindo da imagem limpa v1.0; o `flash_release.sh` da v12n (lista de 269 blocos conferida só offline).
