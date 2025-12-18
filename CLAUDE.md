# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MaxiFlora Agent is an N8N-based AI customer service workflow for MaxiFlora Farmácia de Manipulação (custom pharmaceutical compounding pharmacy) in Brusque, SC, Brazil. The agent named "Flora" handles customer inquiries via WhatsApp/chat.

## Architecture

```
Client Message (WhatsApp)
       ↓
   N8N Webhook
       ↓
 Atendente2 Agent (LangChain + GPT-4.1)
       ├→ HTTP Request: fetch instructions from GitHub
       ├→ Postgres Chat Memory: load conversation context
       ├→ Parallel Tools:
       │  ├→ search_products (Supabase vector DB)
       │  └→ search_ingredientes_ativos (Supabase vector DB)
       └→ Refletir (thinking/reasoning tool)
       ↓
 Response to Client + Store in Chat Memory
```

### Key Components

| File | Purpose |
|------|---------|
| `AGENTE PRINCIPAL MAXIFLORA.md` | Agent behavior instructions, decision flow, business rules |
| `workflow_n8n.json` | N8N workflow configuration (import into N8N to deploy) |
| `.mcp.json` | MCP server config for Supabase integration |

### External Services

- **N8N**: Workflow automation platform
- **OpenAI GPT-4.1**: LLM backbone (temperature: 0 for deterministic responses)
- **Supabase**: Vector database for products (`documents` table) and ingredients (`manipulados_farma` table)
- **PostgreSQL**: Chat history storage (`n8n_chat_histories_maxiflora` table)

## Deployment

1. Import `workflow_n8n.json` into N8N instance
2. Configure credentials: OpenAI API, Supabase API, PostgreSQL connection
3. Activate workflow and configure webhook trigger

## Updating Agent Behavior

Edit `AGENTE PRINCIPAL MAXIFLORA.md` and push to GitHub. The workflow fetches instructions dynamically via HTTP Request node.

## Agent Decision Flow

The agent follows 4 sequential decision steps before responding:

1. **Photo/Document Detection**: Prescriptions, formulas with dosages, CRM/RQE → Immediate transfer
2. **Repurchase Detection**: "de novo", "sempre compro", specific product mentions → Immediate transfer
3. **Quote Request**: "orçar", "orçamento" → Immediate transfer
4. **Specific Product/Ingredient**: Execute parallel searches, otherwise qualify lead first

## Database Structure

- **Session Key**: Customer phone number
- **Context Window**: 10 messages
- **Products Table**: `documents` (filter: `ecommerce=irrobacsv`)
- **Ingredients Table**: `manipulados_farma` (filter: `estoque=principiosativos`)

## Critical Business Rules

- Always ask customer's full name on first interaction
- Never invent product information; transfer if unsure
- Can't provide manipulation status (direct to phone: 47 3355-5417)
- Transfer for: payments, order status, negotiations, delivery issues
- Delivery fees vary by neighborhood (R$ 13-30 in Brusque)

## Gerenciamento do Banco de Dados (MCP Supabase)

O projeto usa MCP Supabase para gerenciar dados. Use as ferramentas `mcp__supabase__*` para operações no banco.

### Informações do Projeto

- **Project ID**: `pevhcqefgzczilutmcup`
- **Project Name**: `bot_new`
- **URL**: `https://pevhcqefgzczilutmcup.supabase.co`

### Estrutura da Tabela `documents`

```sql
id: bigint (auto-increment)
content: text
metadata: jsonb
embedding: vector(1536)
```

### Inserir Matéria-Prima (Princípio Ativo)

```sql
INSERT INTO documents (content, metadata) VALUES (
  'materias_primas: NOME_DO_ATIVO',
  '{"estoque": "principiosativos", "source": "blob", "blobType": "text/csv"}'::jsonb
);
```

### Inserir Produto Pronto

```sql
INSERT INTO documents (content, metadata) VALUES (
  'nome: NOME_PRODUTO | descricao: DESCRICAO | preco: XX.XX',
  '{"ecommerce": "irrobacsv", "source": "blob", "blobType": "text/csv"}'::jsonb
);
```

### Editar Registro

```sql
UPDATE documents SET content = 'novo conteudo' WHERE id = ID_DO_REGISTRO;
```

### Consultar Registros

```sql
-- Listar matérias-primas
SELECT id, content FROM documents WHERE metadata->>'estoque' = 'principiosativos';

-- Listar produtos
SELECT id, content FROM documents WHERE metadata->>'ecommerce' = 'irrobacsv';

-- Buscar por nome
SELECT id, content FROM documents WHERE content ILIKE '%termo%';
```

### Gerar Embedding (Obrigatório para Busca Vetorial)

Após inserir um registro, é necessário gerar o embedding para que a busca vetorial funcione. Use curl para chamar a API OpenAI:

```bash
# 1. Gerar embedding
curl -s https://api.openai.com/v1/embeddings \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"input": "CONTEUDO_DO_REGISTRO", "model": "text-embedding-ada-002"}' \
  | jq -c '.data[0].embedding' > /tmp/embedding.json

# 2. Criar payload
jq -c '{embedding: .}' /tmp/embedding.json > /tmp/payload.json

# 3. Atualizar no Supabase
curl -X PATCH "https://pevhcqefgzczilutmcup.supabase.co/rest/v1/documents?id=eq.ID_DO_REGISTRO" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d @/tmp/payload.json
```

### Credenciais Necessárias

- **OPENAI_API_KEY**: Chave da API OpenAI para gerar embeddings
- **SUPABASE_SERVICE_KEY**: Service role key do Supabase (Settings > API > service_role)
