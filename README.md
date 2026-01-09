# Norxcoin (NORX) - Core Smart Contracts

Este repositório contém os contratos inteligentes oficiais do ecossistema **Norxcoin**. Nosso projeto nasceu com a missão de fornecer uma infraestrutura de pagamentos sólida para além da bolha cryto através do **NorxPay**.

## 🚀 Visão de Soberania (NSC)
Atualmente operando na rede BSC, a Norxcoin está em processo de transição para sua própria rede independente, a **Norx Smart Chain (NSC)**. O objetivo é eliminar a dependência de liquidez externa e garantir taxas mínimas para nossos usuários.

## 📊 Tokenomics & Distribuição
O fornecimento total inicial foi de **1.500.000_000 NORX**, distribuídos da seguinte forma:

* **25% - Queima Inicial:** 375.000.000 tokens (Deflação imediata).
* **25% - Liquidez PancakeSwap:** 375.000.000 tokens para garantir trocas saudáveis.
* **20% - Norx Company:** 300.000.000 tokens (Reserva estratégica).
* **20% - Recompensas & Staking:** 300.000.000 tokens para incentivar a comunidade.
* **5% - Equipe (Vesting):** 75.000.000 tokens bloqueados para o time.
* **5% - Conta Pessoal:** 75.000.000 tokens (Atualmente 100% alocados em Staking).

## 🛡️ Endereços Oficiais de Gestão
Para total transparência, estas são as carteiras que interagem com o contrato:

* **Admin/Gerenciamento:** `0x797Eb3b6fDfc4f96512eC0061E4D5242FbDED434`
* **Tesouro (Empresa/Investidores):** `0x9C939b953a5C90521C5696b7a9c7f1c9B63A79c6`
* **Staking & Recompensas:** `0x4970f4c3B036Ec47161D9bA3ee6ddA08f51a19d8`
* **Pessoal/Tax Recipient:** `0x2723047a2390b84A913BF445f5cCAd3B16493b6F`

## ⚙️ Funcionalidades do Contrato
* **Taxa de Transferência:** Inicial de 1,5%, limitada a um máximo de 10% para sustentar o ecossistema.
* **Controle de Pausa:** Capacidade de pausar transferências em caso de manutenção ou migração crítica para a rede NSC.
* **Exclusão de Taxas:** Endereços estratégicos (como recompensas e liquidez) são isentos de taxas para otimizar a rede.

## 💰 Contrato de Staking
O ecossistema Norxcoin utiliza um sistema de Staking avançado para recompensar os detentores de longo prazo.
- **Segurança:** Proteção contra Reentrancy e controle de acesso por cargos (ADMIN/MANAGER).
- **Flexibilidade:** Suporte a múltiplos pools com diferentes períodos de bloqueio.
- **Transparência:** Cálculos de APR baseados em blocos da rede.

## 🔒 Vesting da Equipe
Para garantir a sustentabilidade e o compromisso de longo prazo, os tokens da equipe estão sujeitos a um cronograma de liberação controlada (Vesting).
- **Período Total:** 12 meses.
- **Liberação:** 25% a cada 3 meses.
- **Transparência:** O contrato impede a retirada antecipada, alinhando os interesses da equipe com os dos detentores do token.

## 💎 Contrato de Pré-Venda (Presale)
O contrato de pré-venda foi o pilar inicial para a distribuição justa do ecossistema, utilizando um modelo de Tiers para garantir que a comunidade pudesse entrar cedo no projeto.

### 📈 Histórico de Valorização Real
A Norxcoin (NORX) demonstrou um desempenho de mercado excepcional. Quem participou das fases iniciais de pré-venda hoje detém um ativo com valorização massiva.

| Tier de Venda | Preço na Pré-Venda (Tokens por $10) | Preço Atual (09/01/2026) | Valorização (%) |
| :--- | :--- | :--- | :--- |
| **Bronze / Silver / Gold** | ~$0,00010 | **$0,0287** | **+28.600%** |

---

### 🛠 Detalhes Técnicos da Pré-Venda
O contrato `NorxcoinPresale.sol` foi implementado com foco em segurança e transparência:
* **Estrutura de Tiers:** Limitação de participantes por categoria (Bronze, Silver e Gold) para evitar a concentração de tokens (Baleias).
* **Segurança:** Implementação de `ReentrancyGuard` e `AccessControl` para proteção contra ataques e gestão de cargos (ADMIN/MANAGER).
* **Gestão de Tesouraria:** Transferência automática de fundos para a `treasuryWallet` e proteção contra envio acidental de BNB via `revert` no `receive()`.
* **Finalização:** Função de encerramento que retira tokens não vendidos da circulação, protegendo o valor dos detentores atuais.

---

## 🌪 Airdrop Deflacionário (Burn-Heavy Model)
O contrato `NorxcoinAirdropDeflacionario.sol` foi projetado para recompensar a comunidade enquanto reduz drasticamente o fornecimento total (Supply) através de um mecanismo de queima 10:1.

### 📉 Mecanismo de Escassez Agressiva
Diferente de airdrops comuns que apenas diluem o token, o modelo da Norxcoin é **extra-deflacionário**:
* **Recompensa do Usuário:** Máximo de 140 NORX por participante.
* **Queima Obrigatória (Burn):** Ao realizar o *claim*, o contrato executava automaticamente a queima de **10x o valor recebido**.
* **Exemplo:** Se um usuário reivindica **140 NORX**, o contrato queima **1.400 NORX** permanentemente da circulação.

> "A Norxcoin foi construída para se tornar cada vez mais rara à medida que a comunidade cresce."

---

### 🛠 Regras e Recompensas
O contrato gerenciava um sistema de tarefas sociais para engajamento orgânico:
* **Tarefas Sociais (Twitter, Telegram, Insta, YT):** 15 NORX cada.
* **Bônus de Engajamento:** Likes e Retweets bônus.
* **Sistema de Referência:** 55 NORX por indicação (limitado a 5 convites).

### 🔒 Funções de Segurança Integradas
* **Controle de Owner:** Apenas o administrador pode validar a conclusão das tarefas, evitando bots.
* **Emergency Withdraw:** Proteção para recuperação de tokens em caso de necessidade de atualização.
* **One-time Claim:** Mapeamento rigoroso (`hasClaimed`) para garantir que cada carteira participe apenas uma vez.


## 🛒 Sistema de Compra Direta no Site Oficial (www.norxcompany.com.br)
O contrato `NORXCoinOTC.sol` gerencia as compras feitas diretamente pelo site oficial usando BNB ou USDT. Ele foi desenhado para ser o motor de valorização contínua do ecossistema Norxcoin.

### ⚖️ O Diferencial: Queima Justa (Bonus Burn)
Um dos pontos mais importantes do nosso modelo econômico é que a **Deflação não penaliza o investidor**. 

Diferente de outros tokens onde a queima é retirada do valor que o usuário compra, na Norxcoin:
* **O Usuário recebe o que pagou:** Se você compra 1.000 NORX, a queima de 10% (100 NORX) é gerada como um **custo extra do contrato**.
* **Impacto Real:** Para cada compra, o contrato retira do próprio estoque uma quantidade adicional de tokens e os envia para a `DEAD_WALLET`, acelerando a escassez sem reduzir o saldo do comprador.

**Exemplo de Transação (1.000 NORX):**
1. **Comprador recebe:** 985 NORX (após taxa de serviço de 1.5%).
2. **Taxa de Serviço:** 15 NORX (destinados à manutenção do ecossistema).
3. **Queima (BURN):** **100 NORX são destruídos para sempre.**
4. **Total saindo do estoque:** 1.100 NORX.

---

### 🛠 Funcionalidades de Alta Tecnologia
* **Oracle Chainlink:** Integração em tempo real com o feed de preços da Chainlink para garantir que o valor em BNB/USDT seja sempre justo e atualizado.
* **Segurança Multi-Nível:** Proteção contra reentrância (`ReentrancyGuard`) e controle de pausa para emergências.
* **Transparência Total:** Todas as queimas e taxas são registradas em eventos on-chain, auditáveis por qualquer pessoa via BscScan.
