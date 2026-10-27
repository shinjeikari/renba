# Controles (testados nesta box)

A box **não tem Bluetooth utilizável** (sem chip BT na UART, kernel sem `btusb`; evidências em `logs/bt_check*.log`, `bt_probe.log`).
Para jogar sem fio, use um **adaptador USB 8BitDo** (aparece como "Microsoft X-Box 360 pad", driver `xpad`).

| Controle | Ligação | Resultado |
|---|---|---|
| DualShock 4 (Sony, `054c:09cc`, driver hid-sony) | cabo USB direto na box | funciona (verificado por adb e jogando) |
| Adaptador USB 8BitDo (`2dc8:3107`) + controle | sem fio | funciona; sem controle ligado aparece como "8BitDo IDLE" |
| Controle PS4 original | via adaptador 8BitDo | relatado pelo usuário como funcionando |
| Controle PS5 original | via adaptador 8BitDo | relatado pelo usuário como funcionando |
| Q300 (genérico estilo PS4) | via adaptador 8BitDo | relatado pelo usuário como funcionando |
| RH 5188 (genérico estilo PS5) | via adaptador 8BitDo | relatado pelo usuário como funcionando |

Receptor 2,4 GHz de outro controle (`045e:028e`, "TGZ Controller", porta 2): a box o reconhece como "Microsoft X-Box 360 pad" (xpad), mas sem o controle original pareado não houve teste de jogo.

Não testados: (1) dongle Bluetooth USB: não foi testado; o kernel não tem o driver `btusb` (`CONFIG_BT_HCIBTUSB is not set`), então a expectativa é que não funcione, mas é dedução da configuração, não teste. (2) receptor 2,4 GHz: ver acima.

## Botões
- Pegasus: L1/R1 trocam de aba; X/Confirmar entra; Bola = voltar/menu (padrão do Pegasus).
- Jogo: **Select + Start** juntos, apertados 2x = sair do jogo. Analógico esquerdo funciona como direcional.
- Controle remoto IR: 4/6 trocam de aba, 9 = ESC (2x para sair do jogo), seta curva = Voltar.
- Aviso "controle não configurado": evitado pelos perfis em `<cartão>/Android/data/com.retroarch.ra32/files/autoconfig`.
