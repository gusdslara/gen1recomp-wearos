# ROM de desenvolvimento

Coloque aqui o seu **Pokémon FireRed (USA) v1.0** (`.gba`,
SHA-1 `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc`).

Os builds **debug** do módulo `:wear` empacotam esse arquivo dentro do
`game.love` (em `devrom/`). No primeiro start o relógio importa a ROM sozinho,
sem launcher e sem `adb push`, e depois abre direto no jogo.

- Builds **release** nunca incluem a ROM.
- `*.gba` está no `.gitignore`, então ela não vai para o repositório.
- Para gerar um debug sem a ROM: `gradlew :wear:assembleDebug -PwearNoRom`.
