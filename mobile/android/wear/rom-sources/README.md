# ROMs de referência para as traduções (só no seu PC)

Esta pasta **não entra em nenhum build release**. Os builds **debug** empacotam
as ROMs `firered_ptbr/es/fr/it.gba` no `game.love` (em `idioma/`), para o relógio de
desenvolvimento já abrir o jogo no idioma dele (`-PwearLangs=pt` leva só o português,
`-PwearLangs=none` nenhuma). `*.gba` já está no `.gitignore`. A ferramenta de receitas lê daqui e gera só
tabelas de endereços; nenhum texto das ROMs vai para o app release.

| Arquivo | ROM | Código no cabeçalho |
| --- | --- | --- |
| `firered_es.gba` | a ROM USA 1.0 com um patch de tradução espanhol aplicado (a cópia atual é essa, não a oficial BPRS) | BPRE |
| `firered_fr.gba` | Pokemon - Version Rouge Feu (France) | BPRF |
| `firered_de.gba` | Pokemon - Feuerrote Edition (Germany) | BPRD |
| `firered_it.gba` *(opcional)* | Pokemon - Versione Rosso Fuoco (Italy) | BPRI |
| `firered_ptbr.gba` + o patch (`.ips`/`.ups`) | a ROM USA 1.0 com um patch de tradução PT-BR aplicado | BPRE |
| `firered_ru.gba` + o patch *(opcional)* | a ROM USA 1.0 com um patch de tradução russo aplicado | BPRE |

A ROM americana (Pokemon - FireRed Version (USA), 1.0) já está em `../dev-rom/`.
Para os patches de fãs, deixe junto um `.txt` com o nome do grupo e a versão do patch.
