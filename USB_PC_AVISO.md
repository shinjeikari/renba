# AVISO: nao ligue esta TV Box a um computador pela porta USB

Resumo: na box testada ("MXQ Pro 4K", Allwinner sun50iw9p1) **nenhuma porta USB funciona como "dispositivo" para um PC**, e ligar a porta ao lado do conector AV a um notebook causou um alerta de **sobrecorrente no Windows**. Nao ha correcao por software. Use adb por rede.

## O que aconteceu
Cabo USB-A macho -> USB-C macho entre a porta da box (ao lado do AV) e um notebook Windows 11, com o "USBV device mode" ligado e o papel da porta forcado para dispositivo.
O Windows mostrou esta notificacao (texto original, em portugues):

> **Surto de tensão na porta USB**
> Dispositivo USB desconhecido precisa de mais energia do que a capacidade de fornecimento da porta.

(Captura de tela da notificacao: `evidencias/windows_surto_tensao.png`, se incluida no repositorio.)

## Medidas na box (somente leitura, via adb)
- Quatro portas = quatro controladores USB: `usbc0` (5100000, unica com UDC) + `ehci1`/`ehci2`/`ehci3` (so host). A porta ao lado do AV e a `usbc0` (por eliminacao: com o modo dispositivo ligado nada e detectado nela; mouse e teclado funcionam nas outras tres).
- Device-tree `usbc0`: `usb_port_type = 1` (host), `usb_detect_type = 1`, `usb_id_gpio` e `usb_det_vbus_gpio` **vazios** (sem deteccao de VBUS nem de ID).
- Com `otg_role = usb_device`: `/sys/class/udc/5100000.udc-controller/state` fica **`not attached`** e `current_speed` = `UNKNOWN`, mesmo com cabo ligado e recolocado; o PC nao enumera nada (nenhum VID_18D1 / VID_1F3A / dispositivo desconhecido valido).
- `soft_connect` (sysfs) nao ajuda.

## Interpretacao (nao confirmada por esquematico)
O 5 V da porta A parece ser fornecido pela propria box como saida fixa (porta so de host) e o SoC nao tem sensor de VBUS ligado. Ao ligar a um PC, as duas pontas ficam com 5 V -> o Windows corta a porta por sobrecorrente. E problema de hardware; mudar o device-tree dentro do `boot.img` nao e recomendado (exige gravar a particao `boot`, sem caminho de recuperacao provado).

## O que fazer
- Nao ligue a porta USB desta box a PC/notebook.
- Instale esta imagem por **adb por rede** (opcao "USBV device mode" ligada na box).
- Se ja ligou e viu o aviso, desconecte; o Windows desliga a porta por protecao. Nao ha dano conhecido, mas nao repita.
