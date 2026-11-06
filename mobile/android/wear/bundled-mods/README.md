# Mods pré-instalados no relógio

Cada pasta aqui entra no `game.love` como `mods/<pasta>/` em **todos** os builds do
módulo `:wear` (o carregador de mods acha elas junto com as que estiverem na pasta de
save). Mod sem escolha salva de liga/desliga começa ligado.
`gradlew :wear:assembleDebug -PwearNoMods` gera sem elas.

| Pasta | Mod | Versão | Origem |
| --- | --- | --- | --- |
| `voxel_world_gen3` | Voxel Diorama (Gen 3), de Tooandorisu: o mundo do FireRed em 3D voxel | 1.32.1 | https://github.com/Tooandorisu/Voxel-Diorama |

Para atualizar: baixe o zip da release nova do autor e troque a pasta inteira.

> O repositório do Voxel Diorama não declara licença. Para uso pessoal tudo bem; antes
> de **publicar** um APK com ele embutido, peça permissão ao autor (ou troque por um
> download no primeiro start).

Alterações na cópia embutida (só em `voxel_world_gen3/main.lua`, marcadas com "wear port"):
- todos os padrões de opção no mais leve, e a vista começa em OFF (2D);
- o código 3D (`voxel/`) só é carregado na primeira vez que a vista é ligada;
- `mod.exports.status()` (o motivo de o 3D não estar desenhando), que o relógio mostra no
  centro da tela, porque os avisos do próprio mod saem na borda de cima, que o círculo corta;
- `mod.exports.setLevel()` instala o 3D na hora, se ainda não estiver carregado.
Ao atualizar o mod, reaplique essas mudanças.
