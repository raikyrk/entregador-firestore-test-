# Ao Gosto Entregador

**Aplicativo oficial dos entregadores parceiros da Ao Gosto Carnes**  
Um app rápido, moderno e inteligente para gerenciar entregas, escanear QR Codes, acompanhar ganhos e performance.

> **Status do projeto:** 
Em produção ativa 
Atualizado automaticamente via Shorebird 
 +20 entregadores usando diariamente

## Funcionalidades

| Recurso                              | Status  | Descrição |
|-------------------------------------|--------|---------|
| Login por PIN de 4 dígitos          | Done    | Seguro e rápido |
| Dashboard com estatísticas diárias  | Done    | Entregas do dia, tempo médio, comparativo com ontem |
| Scanner QR Code com animação premium| Done    | Linha animada + borda pulsante + overlay glassmorphism |
| Lista de entregas (Em Andamento / Concluídas) | Done | Filtro por data, valor total a receber |
| Marcar como Concluído               | Done    | Com cálculo automático de duração |
| Devolver ao processamento          | Done    | Caso tenha pego errado |
| Abrir no Google Maps ou Waze        | Done    | Um toque só |
| Ligar para o cliente                | Done    | Direto do app |
| SMS automático ao cliente           | Done    | "Saiu pra entrega" e "Entrega concluída" |
| Lembrete após 1h de pedido pendente | Done    | Notificação inteligente |
| Atualizações automáticas (Shorebird)| Done    | Sem precisar atualizar na Play Store |
| Atualização forçada via API         | Done    | Controle total da versão |
| UI/UX premium (animações, glass, dark cards) | Done | Design que impressiona |

## Tecnologias Utilizadas

```yaml
flutter: Flutter 3.19+
: Firebase Firestore (backend)
: Firebase Authentication (não usado – login por PIN no Firestore)
: Shorebird Code Push (atualizações instantâneas)
: mobile_scanner (leitura de QR Code)
: shared_preferences (persistência local)
: cloud_firestore, firebase_core
: intl, url_launcher, http, permission_handler
: flutter_dotenv (variáveis de ambiente)
: path_provider (logs temporários)
Como Rodar Localmente
Bash# 1. Clone o repositório
git clone https://github.com/seu-usuario/aogosto-entregador.git
cd aogosto-entregador

# 2. Instale as dependências
flutter pub get

# 3. Crie o arquivo .env na raiz
cp .env.example .env

# Preencha com suas credenciais:
# API_BASE_URL=https://seusite.com/api/
# CHECK_UPDATE_ENDPOINT=check-update
# APK_DOWNLOAD_URL=/download/app.apk
# MESSAGE_API_URL=https://api.sms.com/send
# MESSAGE_API_TOKEN=seu_token_aqui

# 4. Rode!
flutter run
Arquivo .env.example (não commitar o real!)`
envAPI_BASE_URL=https://seusite.com/api/
CHECK_UPDATE_ENDPOINT=check-update
APK_DOWNLOAD_URL=/download/app.apk
MESSAGE_API_URL=https://api.suaapi.com/send
MESSAGE_API_TOKEN=abc123xyz
Estrutura do Projeto
textlib/
├── constants/
│   └── delivery_status.dart
├── auth_check.dart              # Verifica login e mostra splash
├── dashboard_screen.dart        # Tela principal com estatísticas
├── deliveries_screen.dart       # Lista completa de entregas
├── login_screen.dart            # PIN de acesso
├── scanner_screen.dart          # Scanner QR Code com animação premium
├── main.dart                   # Bootstrap com Shorebird + splash
└── firebase_options.dart
Atualizações Instantâneas (Shorebird)
O app recebe atualizações sem precisar publicar na Play Store graças ao Shorebird Code Push.
YAMLdependencies:
  shorebird_code_push: ^1.0.0
Quando você fizer um flutter build apk e subir com:
Bashshorebird release android
Todos os entregadores recebem a nova versão em segundos!

<<<<<<< HEAD
Ao Gosto Carnes Nobres - 
=======
Ao Gosto Carnes Nobres - 
>>>>>>> testes
