# Decisões de implementação

Números propostos, a calibrar pela simulação. Nenhuma regra travada do plano foi alterada.

1. **Item como `Dictionary`**, não Resource: serializa direto para save e rede.
2. **Sem `class_name`**: o núcleo usa `preload`, para rodar em headless sem cache de importação.
3. **Fortuna e Piedade** movem pontos dos doadores (T5, T4, proporcional ao peso) para T1 e T2.
   Só atuam em alvos liberados; se nenhum alvo estiver liberado, não mexem em nada.
   Fortuna: +2 pp T1, +4 pp T2. Piedade: +0,5 pp T1 e +1,5 pp T2 por giro, teto de 20.
4. **Crítico da Fortuna** (5%): o valor sai no topo da faixa do tier sorteado.
5. **Piedade** zera quando alguma linha girada sai T3 ou melhor. Ela é do personagem, não do item.
6. **Custo do giro**: `1 Prisma + (1000 + 50 × nível do item) × (1 + 0,75 × travas)` Zen.
7. **Refino**: +12 é o teto do MVP (`refine.mvp_max`); Aurora já está na tabela para a fase 4.
8. **Nível do T1**: 60 como placeholder até o nível máximo ser definido.
9. **Bônus de set** conta slots distintos; duas peças no mesmo slot contam como uma.
10. **Sigilo** usa a tabela liberada com Fortuna, sem Piedade.

## Visual v2 (troca de arte)

11. **Aparelho-alvo mudou** (decisão do dono do projeto): de Android de entrada para aparelhos médios e bons (Galaxy S21, iPhones recentes). Renderer continua Mobile.
12. **Arte grátis Quaternius (CC0)** no lugar do KayKit: proporção realista, mais perto do Torchlight Infinite e do Mu. Só assets grátis por enquanto.
13. **Boneco modular por máscara de osso**: o corpo base é inteiro; cada peça cobre regiões (tronco, braços, mãos, pernas, pés) e o shader descarta a pele desses ossos. Comum usa roupa de Camponês; Superior e Set usam Patrulheiro; cor e brilho vêm do set/raridade.
14. **Mobs humanoides** no mesmo estilo (carniçais, encapuzados, saqueadores, conjuradores), vestidos por dados em `data/mobs.json`.
15. **Temas de mapa** em `data/themes.json`: floresta (árvores e pedras como borda, grama espalhada, chão procedural), ruínas e praça (muros e lajotas). Do lado da câmera a borda é baixa para não esconder o herói.
