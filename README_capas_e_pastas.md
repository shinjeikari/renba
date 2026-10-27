# RENBA — adicionar jogos e capas

## Pastas
Tudo fica no **cartao SD** (a memoria interna da box guarda so o sistema): `<cartao>/ROMs/<sistema>/`. Sem cartao so aparecem as abas Android e Sistema.
Sistemas: `nes`, `gb` (gb, gbc), `gba`, `snes` (sfc, smc), `megadrive` (md, gen), `mastersystem` (sms), `atari2600` (a26, bin), `psx` (arquivo .cue com o .bin).
Jeito mais facil de enviar jogos sem tirar o cartao: aba **Sistema > Colocar jogos** (servidor FTP com senha; no computador, abra o endereco mostrado no Explorador de Arquivos). Quando terminar, toque em **Terminei**: o menu atualiza sozinho.

## Capas (boxFront)
O Pegasus procura a capa em `media/<nome da ROM sem extensao>/boxFront.png` (ou .jpg) **dentro da pasta de cada sistema**.
Cada sistema tem a sua propria pasta `media`. Exemplo:

```
nes/
  Mario Bros.nes
  Mega Man.nes
  media/
    Mario Bros/boxFront.png
    Mega Man/boxFront.png
```

- O nome da pasta tem de ser igual ao da ROM, sem a extensao (maiusculas e espacos iguais).
- Se colocar todas as capas numa unica pasta `media` na raiz de ROMs, o Pegasus nao encontra.
- `logo` e `video` seguem a mesma regra. Para muitos jogos, use um scraper (Skraper, Skyscraper).
- **Download automatico:** depois de enviar os jogos, a TV Box baixa as capas sozinha (site libretro-thumbnails, nomes No-Intro como `Keystone Kapers (USA)`). Se o nome do arquivo tiver outro formato, ela tenta o titulo sem as etiquetas `(...)` com as regioes USA, Europe, World e Japan. Hacks, jogos novos de autores independentes e traducoes nao costumam ter capa la: ponha o seu `boxFront.png` na pasta do jogo. Os jogos sem capa online ficam anotados em `media/.sem_capa` (apague esse arquivo para tentar de novo).
- **Hacks, traducoes e jogos independentes: a capa NAO e baixada** (nao existe no banco online). Tem que ser feita a mao: renomeie a imagem para `boxFront.png` e coloque em `<sistema>/media/<nome do arquivo do jogo sem extensao>/`, depois toque em **Terminei**. A tela "Capas dos jogos" mostra, ao terminar, a lista dos jogos sem capa e o botao **Como colocar a capa a mao** com o passo a passo.
- Doc oficial: https://pegasus-frontend.org/docs/user-guide/meta-assets/

## Aba Sistema
Fica em `ROMs/sistema/metadata.pegasus.txt` e a pasta `ROMs/sistema` precisa estar no `game_dirs.txt` do Pegasus
(o Pegasus so le um metadata por pasta listada; no mesmo arquivo das colecoes os atalhos apareciam em todas as abas).

## Fundo de cada console
O tema do Pegasus só usa fundo **por jogo**: `<sistema>/media/<nome da ROM>/background.jpg` (ou .png). A imagem já traz um fundo ilustrado para cada console e, em todo boot, copia esse fundo para os jogos que ainda não têm um. Para usar um fundo seu num jogo, coloque o arquivo `background.jpg` na pasta `media/<nome da ROM>/` (ele não é sobrescrito). `assets.background` na coleção não é usado por este tema.
