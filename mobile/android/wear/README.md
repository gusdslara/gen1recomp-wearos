# FireRed para Wear OS (Galaxy Watch 7 e afins)

Port para relógio do **gen1recomp / G1R Deluxe**, a recriação nativa em Lua/LÖVE
que já roda no Android e tem FireRed/LeafGreen (beta) com o modo 3D **TILT**
(estilo HD-2D), zoom de câmera e jogo online.

Este módulo `:wear` reaproveita a engine Android que já vem no repositório
(`mobile/android/love`, LÖVE 11.5 + SDL2) e acrescenta:

- **Controles por gestos** na tela inteira, sem botões desenhados por cima do jogo
- **Renderização para tela redonda, sem bordas pretas**: o mapa preenche o círculo
  inteiro e a interface (textos, menus, batalha) fica inscrita no círculo, sem cantos
  cortados. Nas telas que são só interface (abertura, menus, batalha) a borda em volta é
  preenchida com uma extensão desfocada e escurecida da própria imagem
- **Economia de bateria**: perfil de desempenho "WATCH" (30 FPS, sem shaders nem
  survey zoom) e a tela pode apagar sozinha após 60 s sem toque
- Abre **como um app nativo**: direto no FireRed, sem launcher. Com save já cai no menu
  CONTINUE; sem save, na tela de título (pula a abertura). EXIT no menu fecha o app
- Build **debug** pode trazer a ROM embutida (pasta `wear/dev-rom/`) e importa sozinho
- **3D de verdade já instalado**: o mod Voxel Diorama (Gen 3) vem embutido
  (`wear/bundled-mods/`). O jogo abre em 2D e o código 3D nem é carregado; dois toques
  com três dedos ligam/desligam o 3D (com tela "Carregando 3D"), tudo na configuração
  mais leve do mod
- **Idioma automático** pelo idioma do relógio (pt-BR, es, en, fr, de, ru) nas telas do
  próprio port; o texto do jogo segue o mod de tradução daquele idioma, se houver

## Controles

| Gesto | Botão / ação |
| --- | --- |
| Deslizar ↑ ↓ ← → | Direcional (um toque rápido = 1 passo / 1 item de menu) |
| Deslizar e manter o dedo | Continua andando; arraste o dedo pela tela para mudar de direção, como um analógico (o centro do analógico acompanha o dedo, sempre um pouco atrás) |
| Continuar arrastando longe de onde o deslize começou (no mapa) | **Correr** (segura B por você). Só funciona andando livre no mapa, nunca em menus, então não cancela nada sem querer |
| Toque em cima, à esquerda | **L** |
| Toque em cima, no centro | **SELECT** (item registrado, ex.: bicicleta) |
| Toque em cima, à direita | **R** |
| Toque no meio, metade direita | **A** |
| Toque no meio, metade esquerda | **B** |
| Toque na parte de baixo | **START** |
| Segundo dedo enquanto o primeiro anda | O botão da zona onde o segundo dedo encosta, segurado enquanto ele fica na tela (o primeiro continua andando) |
| Dois dedos deslizando ← / → | **L / R** |
| Dois toques com três dedos | Liga/desliga o **3D** (vista voxel; sem o mod, o TILT). Toque com dois dedos não faz nada, de propósito |
| Toque com quatro dedos | Liga/desliga o painel de diagnóstico (tamanhos de janela/display, centro usado e estado do 3D) |
| Girar bezel / coroa / touch bezel | Em menus, batalha e listas: sobe/desce. No mapa: zoom da câmera (horário aproxima) |
| Botão Voltar do relógio | **START** |
| Botão Home | Sai do jogo (ele fica pausado em segundo plano) |

Cada botão apertado acende um arco curto no aro, na posição daquele botão (A à direita, B à
esquerda, START embaixo, SELECT em cima, L/R nas diagonais de cima), com a letra logo dentro;
o direcional usa o arco branco (laranja quando está correndo). Um resumo dos controles aparece
na tela por 7 s ao abrir o jogo; qualquer toque fecha.

> Os gestos de deslizar da esquerda para a direita normalmente fecham apps no Wear OS.
> O tema do app desliga esse "swipe to dismiss", senão andar para a direita fecharia o jogo.

## Compilar e instalar (Windows + Android Studio)

1. No Android Studio: **File > Open** e abra a pasta `gen1recomp\mobile\android`
   (não a raiz do repositório).
2. No **SDK Manager** instale: Android SDK Platform **36**, Build-Tools 36.x e
   **NDK 25.2.9519653** (aba *SDK Tools*, marque *Show Package Details*). O Gradle usa JDK 17,
   que já vem com o Android Studio.
3. Aguarde o Gradle sync. Na barra de execução escolha a configuração **wear**.
4. Conecte o relógio por **depuração Wi-Fi**: no Galaxy Watch, *Configurações > Sobre o
   relógio > Informações do software*, toque 5x em *Versão do software*; depois
   *Opções do desenvolvedor > Depuração ADB* e *Depurar via Wi-Fi*. No PC:
   `adb pair IP:PORTA` (código do relógio) e `adb connect IP:PORTA`.
5. Clique em **Run**. A primeira compilação é demorada (compila LuaJIT, SDL e LÖVE para cada ABI).

O `game.love` (o jogo em Lua) é empacotado automaticamente pela task
`packDebugGameLove`/`packReleaseGameLove`, sem precisar de bash nem dos scripts do projeto.

Também dá pelo terminal, dentro de `mobile\android`:

```bat
gradlew :wear:assembleDebug
adb install -r wear\build\outputs\apk\debug\wear-debug.apk
```

## A ROM (obrigatória, uma vez)

**Desenvolvimento:** coloque o `.gba` em `mobile/android/wear/dev-rom/` (já está no
`.gitignore`). Todo build **debug** empacota essa ROM dentro do `game.love`; no primeiro
start o relógio mostra "Preparando FireRed" com o progresso, importa sozinho e entra no
jogo. Nada de launcher nem `adb push`. Builds **release** nunca levam a ROM, e
`gradlew :wear:assembleDebug -PwearNoRom` gera um debug sem ela.

**Sem ROM embutida** (release): o relógio abre numa tela redonda "Envie a ROM" com a pasta
de destino, fica olhando essa pasta e, assim que o `.gba` chega, mostra "Preparando FireRed",
importa, apaga a cópia e entra no jogo, igual ao build de dev. Sem launcher.

O jogo não traz nenhum arquivo da Nintendo: ele lê a sua ROM na primeira execução e
gera os dados a partir dela. É aceita somente **Pokémon FireRed (USA) v1.0**,
SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`.

O Wear OS não tem seletor de arquivos, então envie a ROM por ADB:

```bat
adb push "FireRed.gba" /sdcard/Android/data/com.wearports.firered/files/save/pokemon-love2d/
```

Pode enviar com o app aberto na tela de espera ou fechado. A importação no relógio pode levar
alguns minutos; depois disso o app abre direto no jogo.

Os saves ficam na mesma pasta, então dá para fazer backup com `adb pull`.

## 3D e idioma

**3D:** `wear/bundled-mods/voxel_world_gen3` (Voxel Diorama 1.32.1, de Tooandorisu) entra
em todo build como mod pré-instalado. A cópia embutida foi ajustada para o relógio:
começa desligada (2D) e só carrega o código 3D na primeira vez que é ligada, e todos os
padrões estão no mais leve (qualidade POTATO, resolução PIXEL, 3D a cada dois quadros,
sem sombras, reflexos, clima 3D, árvores/telhados arredondados, partículas, construção dos
mapas vizinhos etc.). Dá para subir em OPTIONS > MODS. Para tirar o mod: `-PwearNoMods`. O repositório do mod não declara licença: antes de publicar um APK com
ele dentro, peça permissão ao autor.

**Idioma:** o Android passa o idioma do relógio (`POKEPORT_LOCALE`) e o port escolhe entre
português (Brasil), espanhol, inglês, francês, alemão e russo (o resto cai em inglês). Isso
vale para as telas do port (espera/importação da ROM e resumo de controles, na fonte Plain
Pixel do motor, que tem acentos e cirílico). Os diálogos, menus, nomes de golpes e itens do
FireRed vêm da ROM: em cada start o port liga o mod de tradução do idioma do relógio e
desliga os outros (tabela em `src/core/WatchText.lua`, ou `"language"` no manifest do mod).
Hoje o catálogo de mods só tem tradução de FireRed para **alemão**
(`definitiv-german-gen3`, que lê a ROM alemã do próprio jogador). Para os outros idiomas o
jogo continua em inglês até existir um mod de tradução.

## Ajustes finos

Tudo fica em `src/core/Watch.lua`, na tabela `Watch.config`:

| Chave | Padrão | O que faz |
| --- | --- | --- |
| `swipe` | 0.12 | distância (fração do raio) para virar deslize |
| `runRadius` | 0.45 | a partir dessa distância, corre |
| `tapBand` | 0.45 | toques acima/abaixo dessa distância do centro (fração do raio) = faixa de cima (L/SELECT/R) / START |
| `shoulderX` | 0.30 | na faixa de cima, além dessa distância do centro na horizontal = L / R |
| `clampToDisplay` | true | usa só o display real como tela (corrige janela maior que o display) |
| `joystickMax` | 0.25 | o quanto o centro do analógico fica atrás do dedo (fração do raio) |
| `wheelTouchGuard` | 0.4 | giro de coroa/bezel é ignorado com dedo na tela e por esse tempo depois (o "bezel por toque" do Wear OS transforma arrastos curvos em giro) |
| `threeTapGap` | 0.6 | segundos máximos entre os dois toques de três dedos |
| `voxelLevel` | 2 | ângulo da câmera 3D ao ligar: 1 LOW, 2 MID, 3 HIGH |
| `debugOverlay` | false | abre já com o painel de diagnóstico ligado |
| `language` | "auto" | idioma das telas do port e do mod de tradução; ou "pt", "es", "en", "fr", "de", "ru" |
| `minHold` | 0.14 | quanto um deslize rápido segura a direção (garante 1 passo inteiro) |
| `alwaysRun` | false | `true` = sempre corre ao andar no mapa |
| `fit` | "circle" | `"integer"` volta para pixels inteiros (cantos podem sair do círculo) |
| `worldView` | 200 | quantos pixels do GBA cabem no diâmetro da tela no mapa |
| `fill` | "ambient" | `"black"` volta às bordas pretas nas telas só de interface |
| `ambientDim` | 0.55 | brilho da borda desfocada (0 a 1) |
| `idleSleep` | 60 | segundos sem toque até permitir a tela apagar |

O limite de 30 FPS está no perfil `watch` em `src/core/Performance.lua`. Em
*OPTIONS > PERFORMANCE* do jogo dá para trocar AUTO (=WATCH) por HIGH, se quiser 60 FPS.

## Testar no PC sem o relógio

Com LÖVE 11.5 instalado, na raiz do `gen1recomp`:

```bat
set POKEPORT_WATCH=1
set POKEPORT_TOUCH=1
love . --game=firered
```

Abre uma janela quadrada de 480x480 (igual ao Galaxy Watch 7 44mm) e o mouse simula o dedo.
A ROM, nesse caso, é importada pelo launcher normal do desktop.

## O que foi alterado no projeto

Arquivos novos:
- `src/core/Watch.lua`: detecção do modo relógio, ajustes e cálculo de escala para tela redonda
- `src/core/WatchGestures.lua`: reconhecedor de gestos, corrida, bezel e economia de tela
- `src/core/WatchText.lua`: idioma pelo locale do relógio, textos do port em 6 idiomas e
  escolha automática do mod de tradução
- `mobile/android/wear/bundled-mods/`: mods pré-instalados (Voxel Diorama)
- `src/core/WatchBoot.lua`: primeiro start sem launcher: importa a ROM embutida (debug) ou espera
  ela chegar na pasta (release), com telas redondas de espera e progresso
- `mobile/android/wear/`: este módulo (manifest Wear OS standalone, `WearGameActivity`, que
  encerra o processo quando o jogo fecha, para o próximo toque no ícone abrir limpo)

Arquivos existentes (cada trecho marcado com `WEAROS-PATCH`, e nada muda fora do relógio):
- `src/core/TouchControls.lua`: no relógio, repassa toques/desenho para `WatchGestures`
- `src/render/Renderer.lua`: escala inteira do mapa, escala da UI inscrita no círculo e
  preenchimento desfocado das bordas
- `src/ui/game3/boot.lua` + `src/core/Game3.lua`: no relógio, abre direto no menu CONTINUE
  (com save) ou no título (sem save)
- `src/core/game3/display.lua`: o mesmo encaixe redondo no caminho de tela do FRLG, UI centralizada
- `src/core/Performance.lua`: perfil `watch`
- `src/render/Playfield.lua` e `src/core/Orientation.lua`: skins de celular e trava de
  orientação não se aplicam no relógio
- `src/core/Platform.lua`: desliga o auto-update (que baixaria o APK de celular)
- `main.lua`: bezel/coroa passam por `WatchGestures`; no relógio nunca abre o launcher,
  ignora o marcador de "voltar ao launcher", EXIT/fechar encerram o app
- `conf.lua`: janela 480x480 no modo de teste do PC
- `mobile/android/settings.gradle`: inclui o módulo `wear`

## Limitações conhecidas

- O suporte a FireRed no gen1recomp ainda é **beta** no projeto original.
- No emulador Wear OS API 37 a janela do app saiu mais larga que o display (~480x384 num
  384x384), o que descentralizava o jogo. O jogo agora usa só o retângulo do display e o
  app não pede orientação; se ainda aparecer descentralizado, toque com três dedos e mande
  uma captura do painel.
- Uma tela 3:2 nunca cabe inteira num círculo sem sobrar borda: nas telas só de interface o
  conteúdo nítido fica inscrito (para nenhum texto ser cortado) e a borda é o desfoque.
- O efeito de transição para batalha foi pensado para a tela inteira e pode ficar um pouco
  desalinhado na escala redonda.
- O modo 3D (TILT) gasta mais bateria que o 2D.
