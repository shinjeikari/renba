# RENBA — o que a imagem faz (funcionalidades)

Tudo abaixo foi testado na box do autor. O que não foi testado está na última seção.

## Menu e emulação
- **Pegasus Frontend** como tela inicial, com uma aba por console, capas, fundos por console e a aba **Android** (Aurora Store, TV Bro, RetroArch) e a aba **Sistema**.
- **8 consoles** (RetroArch 32 bits): NES (fceumm), Game Boy / Color (gambatte), Game Boy Advance (mgba), Super Nintendo (snes9x), Mega Drive (genesis_plus_gx ou picodrive), Master System (genesis_plus_gx), Atari 2600 (stella), PlayStation 1 (pcsx_rearmed).
- **8 jogos de teste livres**, um por sistema. Nenhuma ROM comercial nem BIOS.
- **Save state:** Select+R1 salva, Select+L1 carrega, Select+direita/esquerda troca o slot. Os estados ficam no cartão.
- **Sair do jogo:** Select+Start duas vezes no controle de jogo, ou botão 9 do remoto (dois toques).

## Tudo no cartão SD
- ROMs, capas, fundos, configuração e saves do RetroArch ficam em `<cartão>/ROMs/` e `<cartão>/Android/data/com.retroarch.ra32/files/`. A memória interna guarda só o sistema.
- O cartão pode ser trocado: o código dele é detectado a cada boot. Sem cartão, aparecem só as abas Android e Sistema.
- Cartão novo: os jogos de teste e as capas deles são semeados uma vez.

## Colocar jogos sem tirar o cartão
- Atalho **Colocar jogos (pelo computador)**: liga um servidor **FTP com senha** (gerada no primeiro boot) e mostra o endereço, o usuário e a senha, com o passo a passo para o Explorador de Arquivos do Windows.
- Faixa de portas passivas (5678–5700): o Explorador envia vários arquivos ao mesmo tempo.
- Botão **Terminei**: desliga o FTP, aplica os fundos, baixa as capas e atualiza o menu sozinho **só se houve novidade** (sem reiniciar a TV Box).

## Capas
- **Download automático** (libretro-thumbnails) para jogos sem capa, a cada boot e quando você toca em **Terminei**. Precisa de internet.
- **Busca tolerante:** tenta o nome exato, depois o título sem etiquetas com as regiões USA, Europe, World e Japan, e por último procura o título principal na lista de nomes do servidor (prefere USA, depois World, depois Europe; ignora hacks e betas).
- **3 tentativas** por download (a conexão às vezes devolve o arquivo cortado) e conferência de PNG e tamanho.
- Tela **Capas dos jogos** com barra de progresso, que se atualiza sozinha; jogos sem capa online ficam anotados em `media/.sem_capa`.
- **Capa à mão** (hacks, traduções, jogos independentes): página **Como colocar a capa à mão**, que lista os jogos sem capa e dá o passo a passo.

## Aba Sistema (atalhos)
Colocar jogos, Capas dos jogos, **Reiniciar a TV Box** (imediato), tela inicial original da box, Configurações do Android, Sobre o dispositivo, Opções de desenvolvedor.

## Controles
- **Remoto IR:** 4 e 6 trocam de aba; 9 = ESC (menu no Pegasus, sair no RetroArch); Voltar = Voltar normal do Android.
- **DualShock 4** por cabo e **adaptadores USB 8BitDo** com controles PS4/PS5/genéricos (os controles pelo adaptador foram relatados pelo autor; o DS4 foi verificado por adb).
- Perfis prontos: não aparece o aviso "controle não configurado".
- O **touchpad** do DS4/DS5 não vira ponteiro de mouse.

## Sistema
- Base: imagem limpa (sem adware, sem `/system/preinstall`, sem OTA do fabricante), `ro.adb.secure=1`, swap em zram, tela de boot **RENBA**.
- **Primeiro boot automático:** instala Pegasus, RetroArch e o servidor FTP, copia os núcleos, define o Pegasus como tela inicial. Leva de 3 a 6 minutos; durante isso a box mostra a tela inicial original.
- **Boot seguinte:** reconhece o cartão, atualiza os fundos, baixa as capas que faltam, limpa abas antigas do TV Bro.
- Scripts de gravação com conferência de **cada bloco** e da imagem inteira; retomam sozinhos se o Wi‑Fi cair.

## Não testado / não suportado
- Outras boxes, outros firmwares ou lotes: só a build de fábrica descrita no README foi testada; relatos de outros são bem-vindos.
- Recuperação com a box sem boot (boot por cartão SD, FEL/PhoenixSuit, recovery de fábrica).
- **Bluetooth** (sem chip utilizável) e **armazenamento USB** (pendrive e leitor não reconhecidos).
- PS1 e jogos pesados sob 1 GB de RAM podem engasgar.
- Ligar a porta USB da box a um computador: não faça (ver `USB_PC_AVISO.md`).
