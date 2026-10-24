# Monitor dos sistemas DF

Confere a cada 5 minutos, de fora da VPS, se os sistemas da DF em `gestaodfsindicos.tech` respondem (`/api/saude` com 200). Pedido do usuário de 2026-10-24, depois de a VPS travar com três deploys ao mesmo tempo e todos os sistemas ficarem fora por cerca de 40 minutos.

- **Situação agora e últimas quedas:** [SITUACAO.md](SITUACAO.md).
- **Aviso:** sistema que não responde em duas tentativas (60 s entre elas) ganha uma issue "Fora do ar: <sistema>" com menção ao dono da conta, que chega por e-mail e no app do GitHub. Quando volta, a issue recebe o tempo fora do ar e é fechada. Uma issue por queda, não uma por rodada.
- **Por que um repositório público:** o GitHub Actions é ilimitado em repositório público e limitado a 2.000 minutos por mês nos privados, que ficam para os deploys. Aqui não há segredo nenhum: só os endereços públicos de `/api/saude`.
- **Limites:** o agendador do GitHub pode atrasar alguns minutos em horários de pico. O GitHub desliga a agenda de repositório público sem commits por 60 dias; o script grava `SITUACAO.md` pelo menos a cada 45 dias para isso não acontecer.
- **Acrescentar um sistema:** uma linha em `sites.txt`.
- **Testar na hora:** Actions → "Monitor" → Run workflow.
