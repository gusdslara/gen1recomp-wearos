# Ferramenta de receitas de tradução (FireRed)

Gera, para cada texto do jogo (chaves de `src/import/gba/versions_text.lua`), o endereço
do mesmo texto numa ROM de outro idioma. A receita só tem **endereços**, nenhum texto.

Como casa os textos (tudo automático, comparando a ROM USA com a outra):
1. **Código** (`spike.py`): o código ARM é igual entre idiomas; cada ponteiro de texto no
   código é achado na outra ROM pelo trecho de código em volta (ponteiros mascarados).
2. **Scripts dos mapas** (`walk.py`): percorre `gMapGroups` -> mapas -> eventos -> scripts
   nas duas ROMs ao mesmo tempo; o bytecode é igual, só os ponteiros de texto mudam.
3. **Tabelas** (`recipe.py`): toda tabela de ponteiros que tenha um item já casado é
   alinhada inteira com a da outra ROM; repete até não achar mais nada.

4. **Bases de tabelas e structs** (`recipe2.py`): mapeia o endereço de cada tabela/registro
   pelo código que aponta para ela e alinha campo a campo, tolerando dados não-ponteiro
   (constantes, endereços de RAM). Repete com os scripts que esses ponteiros alcançam.

Uso (Python 3, ~70 s por idioma; `recipe2.py` ~2 min):

    python3 recipe.py "Pokemon - Version Rouge Feu (France).gba"

(os caminhos das ROMs estão no topo de `spike.py`; ajuste para `rom-sources/`.)

Cobertura dos 3.361 textos nomeados (1ª versão):
| Idioma | Casados |
| --- | --- |
| Francês | 2.273 (68%) |
| Italiano | 2.278 (68%) |
| PT-BR (patch) | 2.078 (62%) |

Falta: textos de batalha, nomes (Pokémon, golpes, itens), ~360 textos sem ponteiro direto,
tabelas de caracteres acentuados, gráficos com texto, e o mod que lê a ROM e aplica.

## Por que não chega a 100% (análise no francês)

Dos 3.361 textos com nome, ~310 **nunca aparecem no jogo americano** e não precisam
de tradução: 290 são sobras em japonês que ficaram na ROM USA, 15 de teste/não usados,
5 rótulos no meio de outro texto. Dos ~3.050 que o jogo mostra, `recipe2.py` casa
2.804 (**~92%**). O resto: ~45 textos que o código monta por deslocamento (sem ponteiro
direto), textos de créditos (a equipe de localização muda por país) e casos isolados.

## No relógio (já ligado)

`src/core/WatchTranslate.lua` aplica a receita no jogo, sem mod:

- No start, o idioma do relógio escolhe a receita (`pt` → `recipe_ptbr.json`,
  `es` → `recipe_es_fanpatch.json`, `fr` → `recipe_fr.json`, `it` → `recipe_it.json`).
  As receitas vão em todo build (`game.love/watchlang/`).
- A ROM do idioma é procurada em `idioma/` (pasta do save, via `adb push`, ou dentro do
  `game.love` nos builds debug, que empacotam `rom-sources/`). Nomes aceitos:
  `firered_ptbr.gba` (ou `firered_pt.gba`), `firered_es.gba`, `firered_fr.gba`, `firered_it.gba`.
- Na primeira vez decodifica os textos (descarta endereços que caem em lixo ou que usam
  placeholders que o motor não conhece) e salva um cache em `watchlang-cache/<idioma>/`;
  nos starts seguintes só carrega o cache. Trocar a receita ou a ROM refaz o cache.
- A fonte também vem da ROM traduzida (achada pelo ponteiro do código ou pela tabela de
  larguras, conferida por um hash das letras), recortada pela largura de cada glifo como o
  GBA faz. É assim que o patch PT-BR mostra ã/õ (ele desenha esses glifos nos códigos de ä/ö).
- Sem receita ou sem ROM para o idioma, o jogo fica em inglês.

Resultado com as receitas atuais (textos aplicados): PT-BR ~2.000, FR ~2.730, IT ~2.230,
ES ~1.680 (a receita do patch espanhol tinha ~350 endereços que caíam em lixo).
