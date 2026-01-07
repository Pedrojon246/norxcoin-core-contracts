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
