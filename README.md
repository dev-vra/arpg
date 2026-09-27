# ARPG

ARPG mobile-first, sucessor espiritual do Mu, com build de temporadas no estilo Torchlight Infinite.
Stack: Godot 4 (renderer Mobile) + Nakama (fase 3). Plano Mestre: https://claude.ai/code/artifact/5beba26b-7e04-46f0-9167-920d2959e5d7

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `core/` | Regras puras, sem cena: tiers, refino, giro, Sigilo, bônus de set, carteira, lotes |
| `data/` | `economy.json`, atributos, sets, catálogo da loja |
| `game/` | Cenas, UI, combate, boneco montado |
| `server/` | Servidor headless e Nakama (fase 3) |
| `tests/` | Unidade, distribuição de tiers, contrato da loja, colisão de nomes |
| `sim/` | Simulador de economia (Fase 0, etapa 4) |
| `docs/` | `naming.md`, `decisions.md` |

## Jogar o MVP

Abra o projeto no Godot 4.4+ e aperte F5, ou rode `godot --path .`.

- **Bastião Cinzento** (base): Vesna (Forja), Ilse (Mentora) e o Portal dos Mapas.
- **3 mapas** com 4 tipos de esqueleto e um chefe cada: Vale Oco, Criptas Rubras e Trono Partido, em Normal ou Difícil.
- **Loop**: matar → coletar (joias por ímã, itens ao encostar) → Forja (refinar, girar com trava, Sigilo) → equipar e ver o boneco mudar.
- **Controles**: toque (joystick à esquerda, ataque/skills/esquiva/poção à direita) ou teclado (WASD, Espaço, 1-4, Shift, Q, E, I, Esc).
- Save local assinado (HMAC) em `user://save_offline.json`.

Os drops do teste estão acelerados por `field_loot.playtest_multiplier` em `data/economy.json` (8x). A simulação usa 1x.

Arte: KayKit (Kay Lousberg, CC0), só como placeholder. Veja `assets/kaykit/README.md`.

## APK

`export_presets.cfg` já tem o preset Android (arm64). Para gerar o APK é preciso instalar os export templates do Godot 4.4.1 e o Android SDK/JDK, e configurar o keystore de debug no editor. Depois: `godot --headless --export-debug Android export/arpg.apk`.

Release (menor, ~30 MB), com a chave passada por variável de ambiente (nunca commitada):
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH=... GODOT_ANDROID_KEYSTORE_RELEASE_USER=... GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... godot --headless --export-release Android export/arpg-mvp.apk`

Animações: só o `Skeleton_Minion.glb` importa animações (15 fps); todos os bonecos usam essa biblioteca via `game/actors/anim_lib.gd` (mesmo rig KayKit).

## Testes

```bash
GODOT=/caminho/do/godot ./run_tests.sh          # tudo
GODOT=/caminho/do/godot ./run_tests.sh spin     # filtra por nome
godot --headless --path . -s tests/smoke_game.gd                   # fumaça do jogo inteiro
xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/screenshots.gd -- /tmp   # capturas
```

O CI (`.github/workflows/tests.yml`) roda a mesma coisa em todo push.

## Regras do núcleo

- Nada falha: refino sempre sobe; giro sempre entrega um tier (T1 melhor, T5 pior).
- Tier só entra no sorteio com nível mínimo e desafio concluído; o bloqueado tem a chance redistribuída.
- Os únicos "não" são pré-condições (sem recurso, nível máximo, trava demais), e nada é consumido nesses casos.
- Toda aleatoriedade passa por `core/rng.gd`, com semente injetável.
