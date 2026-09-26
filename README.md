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

## Testes

```bash
GODOT=/caminho/do/godot ./run_tests.sh          # tudo
GODOT=/caminho/do/godot ./run_tests.sh spin     # filtra por nome
```

O CI (`.github/workflows/tests.yml`) roda a mesma coisa em todo push.

## Regras do núcleo

- Nada falha: refino sempre sobe; giro sempre entrega um tier (T1 melhor, T5 pior).
- Tier só entra no sorteio com nível mínimo e desafio concluído; o bloqueado tem a chance redistribuída.
- Os únicos "não" são pré-condições (sem recurso, nível máximo, trava demais), e nada é consumido nesses casos.
- Toda aleatoriedade passa por `core/rng.gd`, com semente injetável.
