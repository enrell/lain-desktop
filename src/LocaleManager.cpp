#include "LocaleManager.h"

#include <QLocale>
#include <QSettings>

namespace {
const char *kLocaleKey = "locale/selected";

QString normalizeLocale(const QString &locale) {
    const QString v = locale.trimmed().toLower();
    if (v.isEmpty() || v == QStringLiteral("system"))
        return QStringLiteral("system");
    if (v == QStringLiteral("pt") || v == QStringLiteral("pt_br") || v == QStringLiteral("pt-br"))
        return QStringLiteral("pt_BR");
    if (v == QStringLiteral("en") || v == QStringLiteral("en_us") || v == QStringLiteral("en-us"))
        return QStringLiteral("en");
    return QStringLiteral("system");
}
} // namespace

LocaleManager::LocaleManager(QObject *parent) : QTranslator(parent) {
    m_selected = normalizeLocale(QSettings().value(kLocaleKey, QStringLiteral("system")).toString());
    resolve();
}

QVariantList LocaleManager::available() const {
    return {
        QVariantMap{{"id", QStringLiteral("system")}, {"label", tr("System default")}},
        QVariantMap{{"id", QStringLiteral("en")}, {"label", QStringLiteral("English")}},
        QVariantMap{{"id", QStringLiteral("pt_BR")}, {"label", QStringLiteral("Português (Brasil)")}},
    };
}

void LocaleManager::setSelected(const QString &locale) {
    const QString v = normalizeLocale(locale);
    if (v == m_selected)
        return;
    m_selected = v;
    QSettings().setValue(kLocaleKey, v);
    resolve();
    emit localeChanged();
}

void LocaleManager::resolve() {
    QString eff = QStringLiteral("en");
    if (m_selected == QStringLiteral("pt_BR")) {
        eff = QStringLiteral("pt_BR");
    } else if (m_selected == QStringLiteral("en")) {
        eff = QStringLiteral("en");
    } else {
        const QString sys = QLocale::system().name().toLower();
        if (sys.startsWith(QStringLiteral("pt")))
            eff = QStringLiteral("pt_BR");
    }
    m_effective = eff;
    m_dict.clear();
    if (eff == QStringLiteral("pt_BR"))
        loadPt();
}

QString LocaleManager::translate(const char *, const char *sourceText,
                                 const char *, int n) const {
    if (m_effective != QStringLiteral("pt_BR") || !sourceText)
        return {};
    const QString key = QString::fromUtf8(sourceText);
    // Plural-aware fallbacks for legacy %n sources.
    if (key == QStringLiteral("%n result(s)")) {
        QString out = (n == 1) ? QStringLiteral("%n resultado") : QStringLiteral("%n resultados");
        return out.replace(QStringLiteral("%n"), QString::number(n));
    }
    if (key == QStringLiteral("%n title(s)")) {
        QString out = (n == 1) ? QStringLiteral("%n título") : QStringLiteral("%n títulos");
        return out.replace(QStringLiteral("%n"), QString::number(n));
    }
    const auto it = m_dict.constFind(key);
    if (it == m_dict.constEnd())
        return {};
    QString out = it.value();
    if (n >= 0)
        out.replace(QStringLiteral("%n"), QString::number(n));
    return out;
}

void LocaleManager::loadPt() {
    m_dict = {
        {QStringLiteral("Appearance follows the Omarchy theme live, without restarting."),
         QStringLiteral("A aparência segue o tema Omarchy ao vivo, sem reiniciar.")},
        {QStringLiteral("Audio"), QStringLiteral("Áudio")},
        {QStringLiteral("Auto"), QStringLiteral("Automático")},
        {QStringLiteral("Cast"), QStringLiteral("Elenco")},
        {QStringLiteral("Collections"), QStringLiteral("Coleções")},
        {QStringLiteral("Collections are grouped by genre after items receive metadata."),
         QStringLiteral("As coleções são agrupadas por gênero após os itens receberem metadados.")},
        {QStringLiteral("Connected"), QStringLiteral("Conectado")},
        {QStringLiteral("Connecting…"), QStringLiteral("Conectando…")},
        {QStringLiteral("Container"), QStringLiteral("Contêiner")},
        {QStringLiteral("Continue Watching"), QStringLiteral("Continuar assistindo")},
        {QStringLiteral("Could not connect to the server"),
         QStringLiteral("Não foi possível conectar ao servidor")},
        {QStringLiteral("Create a library and scan it to make your media appear here."),
         QStringLiteral("Crie uma biblioteca e escaneie-a para que suas mídias apareçam aqui.")},
        {QStringLiteral("Create account"), QStringLiteral("Criar conta")},
        {QStringLiteral("Enrich"), QStringLiteral("Enriquecer")},
        {QStringLiteral("Extras"), QStringLiteral("Extras")},
        {QStringLiteral("Fetching metadata…"), QStringLiteral("Buscando metadados…")},
        {QStringLiteral("First access"), QStringLiteral("Primeiro acesso")},
        {QStringLiteral("First access — create the administrator account"),
         QStringLiteral("Primeiro acesso — crie a conta de administrador")},
        {QStringLiteral("Font: monospace · Corners mirror Hyprland rounding (%1)"),
         QStringLiteral("Fonte: monospace · Cantos espelham o arredondamento do Hyprland (%1)")},
        {QStringLiteral("Genre"), QStringLiteral("Gênero")},
        {QStringLiteral("Home"), QStringLiteral("Início")},
        {QStringLiteral("Identifier"), QStringLiteral("Identificador")},
        {QStringLiteral("Invalid username or password."), QStringLiteral("Usuário ou senha inválidos.")},
        {QStringLiteral("Item is not available for direct playback."),
         QStringLiteral("Item indisponível para reprodução direta.")},
        {QStringLiteral("Libraries"), QStringLiteral("Bibliotecas")},
        {QStringLiteral("Library"), QStringLiteral("Biblioteca")},
        {QStringLiteral("Media Info"), QStringLiteral("Informações de mídia")},
        {QStringLiteral("Metadata"), QStringLiteral("Metadados")},
        {QStringLiteral("More Info"), QStringLiteral("Mais informações")},
        {QStringLiteral("More Like This"), QStringLiteral("Títulos semelhantes")},
        {QStringLiteral("Movies"), QStringLiteral("Filmes")},
        {QStringLiteral("No collections yet"), QStringLiteral("Sem coleções por enquanto")},
        {QStringLiteral("No libraries are configured on this server."),
         QStringLiteral("Nenhuma biblioteca configurada neste servidor.")},
        {QStringLiteral("No media in this library. Scan it from server settings."),
         QStringLiteral("Sem mídia nesta biblioteca. Escaneie-a nas configurações do servidor.")},
        {QStringLiteral("No media matches this filter."), QStringLiteral("Nenhuma mídia corresponde a este filtro.")},
        {QStringLiteral("No results for ‘%1’"), QStringLiteral("Sem resultados para ‘%1’")},
        {QStringLiteral("Off"), QStringLiteral("Desligado")},
        {QStringLiteral("Offline"), QStringLiteral("Offline")},
        {QStringLiteral("Only administrators can enrich metadata."),
         QStringLiteral("Apenas administradores podem enriquecer metadados.")},
        {QStringLiteral("Only administrators can remove metadata."),
         QStringLiteral("Apenas administradores podem remover metadados.")},
        {QStringLiteral("Overlay from %1"), QStringLiteral("Sobreposição de %1")},
        {QStringLiteral("Overlay from %1 · indexed as “%2”"),
         QStringLiteral("Sobreposição de %1 · indexado como “%2”")},
        {QStringLiteral("Password"), QStringLiteral("Senha")},
        {QStringLiteral("Player"), QStringLiteral("Reprodutor")},
        {QStringLiteral("Preparing playback…"), QStringLiteral("Preparando reprodução…")},
        {QStringLiteral("Recently Added"), QStringLiteral("Adicionados recentemente")},
        {QStringLiteral("Reconnect"), QStringLiteral("Reconectar")},
        {QStringLiteral("Refresh metadata"), QStringLiteral("Atualizar metadados")},
        {QStringLiteral("Remove"), QStringLiteral("Remover")},
        {QStringLiteral("Request failed (%1)"), QStringLiteral("Falha na requisição (%1)")},
        {QStringLiteral("Resuming…"), QStringLiteral("Retomando…")},
        {QStringLiteral("Search library…"), QStringLiteral("Buscar na biblioteca…")},
        {QStringLiteral("Search your library…"), QStringLiteral("Busque na sua biblioteca…")},
        {QStringLiteral("Searching…"), QStringLiteral("Buscando…")},
        {QStringLiteral("Server"), QStringLiteral("Servidor")},
        {QStringLiteral("Session expired. Sign in again."), QStringLiteral("Sessão expirada. Entre novamente.")},
        {QStringLiteral("Settings"), QStringLiteral("Configurações")},
        {QStringLiteral("Shows"), QStringLiteral("Séries")},
        {QStringLiteral("Sign in"), QStringLiteral("Entrar")},
        {QStringLiteral("Sign in to access your library"), QStringLiteral("Entre para acessar sua biblioteca")},
        {QStringLiteral("Sign out"), QStringLiteral("Sair")},
        {QStringLiteral("Size"), QStringLiteral("Tamanho")},
        {QStringLiteral("Sort"), QStringLiteral("Ordenar")},
        {QStringLiteral("Subtitles"), QStringLiteral("Legendas")},
        {QStringLiteral("Suggestions"), QStringLiteral("Sugestões")},
        {QStringLiteral("Test Pattern"), QStringLiteral("Padrão de teste")},
        {QStringLiteral("Test pattern"), QStringLiteral("Padrão de teste")},
        {QStringLiteral("This item has no enriched metadata."),
         QStringLiteral("Este item não possui metadados enriquecidos.")},
        {QStringLiteral("Title"), QStringLiteral("Título")},
        {QStringLiteral("Track %1"), QStringLiteral("Faixa %1")},
        {QStringLiteral("Try again"), QStringLiteral("Tentar novamente")},
        {QStringLiteral("Username"), QStringLiteral("Usuário")},
        {QStringLiteral("View all results  ⏎"), QStringLiteral("Ver todos os resultados  ⏎")},
        {QStringLiteral("Volume %1"), QStringLiteral("Volume %1")},
        {QStringLiteral("Waiting for sign-in"), QStringLiteral("Aguardando login")},
        {QStringLiteral("Year"), QStringLiteral("Ano")},
        {QStringLiteral("Your library is empty"), QStringLiteral("Sua biblioteca está vazia")},
        {QStringLiteral("‹  Back"), QStringLiteral("‹  Voltar")},
        {QStringLiteral("▶  Play"), QStringLiteral("▶  Reproduzir")},
        {QStringLiteral("1 result"), QStringLiteral("1 resultado")},
        {QStringLiteral("%1 results"), QStringLiteral("%1 resultados")},
        {QStringLiteral("1 title"), QStringLiteral("1 título")},
        {QStringLiteral("%1 titles"), QStringLiteral("%1 títulos")},
        {QStringLiteral("All"), QStringLiteral("Todos")},
        {QStringLiteral("HOME"), QStringLiteral("INÍCIO")},
        {QStringLiteral("LIBRARY"), QStringLiteral("BIBLIOTECA")},
        {QStringLiteral("COLLECTIONS"), QStringLiteral("COLEÇÕES")},
        {QStringLiteral("SYSTEM"), QStringLiteral("SISTEMA")},
        {QStringLiteral("Build %1"), QStringLiteral("Compilação %1")},
        {QStringLiteral("Language"), QStringLiteral("Idioma")},
        {QStringLiteral("System default"), QStringLiteral("Padrão do sistema")},
        {QStringLiteral("Anime4K off"), QStringLiteral("Anime4K desligado")},
        {QStringLiteral("shader directory ~/.config/lain/shaders is missing"),
         QStringLiteral("diretório de shaders ~/.config/lain/shaders ausente")},
        {QStringLiteral("no matching shaders in %1"), QStringLiteral("nenhum shader correspondente em %1")},
        {QStringLiteral("Playback error (%1)"), QStringLiteral("Erro de reprodução (%1)")},
        {QStringLiteral("Anime4K %1 · %2/%3 shaders"), QStringLiteral("Anime4K %1 · %2/%3 shaders")},
        {QStringLiteral("User service"), QStringLiteral("Serviço de usuário")},
        {QStringLiteral("Binary"), QStringLiteral("Binário")},
        {QStringLiteral("Checking for a local server and provisioning tools…"),
         QStringLiteral("Verificando servidor local e ferramentas…")},
        {QStringLiteral("Checking for server updates…"), QStringLiteral("Verificando atualizações do servidor…")},
        {QStringLiteral("Could not check for updates."), QStringLiteral("Não foi possível verificar atualizações.")},
        {QStringLiteral("Server update available: %1"), QStringLiteral("Atualização do servidor disponível: %1")},
        {QStringLiteral("Server is up to date."), QStringLiteral("Servidor atualizado.")},
        {QStringLiteral("Found a local server. Connect to avoid duplicates."),
         QStringLiteral("Servidor local encontrado. Conecte-se para evitar duplicatas.")},
        {QStringLiteral("No local server found. Provision a new one or retry."),
         QStringLiteral("Nenhum servidor local encontrado. Provisione um novo ou tente novamente.")},
        {QStringLiteral("Set up your media server"), QStringLiteral("Configure seu servidor de mídia")},
        {QStringLiteral("Connect to the existing server to avoid a duplicate setup."),
         QStringLiteral("Conecte-se ao servidor existente para evitar duplicação.")},
        {QStringLiteral("Connect"), QStringLiteral("Conectar")},
        {QStringLiteral("Set up a new local server"), QStringLiteral("Configurar um novo servidor local")},
        {QStringLiteral("How do you want to run it?"), QStringLiteral("Como você quer executá-lo?")},
        {QStringLiteral("Docker needs a running daemon. Install Docker manually, then return."),
         QStringLiteral("O Docker precisa de um daemon em execução. Instale o Docker manualmente e volte.")},
        {QStringLiteral("Managed by this app"), QStringLiteral("Gerenciado por este app")},
        {QStringLiteral("You can change this later. Provisioning never touches external servers."),
         QStringLiteral("Você pode mudar isso depois. O provisionamento nunca altera servidores externos.")},
        {QStringLiteral("Check for updates"), QStringLiteral("Verificar atualizações")},
        {QStringLiteral("Start"), QStringLiteral("Iniciar")},
        {QStringLiteral("Stop"), QStringLiteral("Parar")},
        {QStringLiteral("Update"), QStringLiteral("Atualizar")},
        {QStringLiteral("User %1 created."), QStringLiteral("Usuário %1 criado.")},
        {QStringLiteral("User disabled."), QStringLiteral("Usuário desativado.")},
        {QStringLiteral("User enabled."), QStringLiteral("Usuário ativado.")},
        {QStringLiteral("User role updated."), QStringLiteral("Função do usuário atualizada.")},
        {QStringLiteral("Password reset."), QStringLiteral("Senha redefinida.")},
        {QStringLiteral("Library %1 created."), QStringLiteral("Biblioteca %1 criada.")},
        {QStringLiteral("Library deleted."), QStringLiteral("Biblioteca excluída.")},
        {QStringLiteral("Scan running…"), QStringLiteral("Escaneamento em execução…")},
        {QStringLiteral("Scan finished."), QStringLiteral("Escaneamento concluído.")},
        {QStringLiteral("Scan failed: %1"), QStringLiteral("Falha no escaneamento: %1")},
        {QStringLiteral("Backup failed."), QStringLiteral("Falha no backup.")},
        {QStringLiteral("Could not write backup file."),
         QStringLiteral("Não foi possível gravar o arquivo de backup.")},
        {QStringLiteral("Backup saved to %1."), QStringLiteral("Backup salvo em %1.")},
        {QStringLiteral("Playing next episode…"), QStringLiteral("Tocando próximo episódio…")},
        {QStringLiteral("Users"), QStringLiteral("Usuários")},
        {QStringLiteral("Make user"), QStringLiteral("Tornar usuário")},
        {QStringLiteral("Make admin"), QStringLiteral("Tornar admin")},
        {QStringLiteral("Disable user %1? They will not be able to sign in."),
         QStringLiteral("Desativar usuário %1? Ele não poderá entrar.")},
        {QStringLiteral("Enable"), QStringLiteral("Ativar")},
        {QStringLiteral("Disable"), QStringLiteral("Desativar")},
        {QStringLiteral("Create user"), QStringLiteral("Criar usuário")},
        {QStringLiteral("Library name"), QStringLiteral("Nome da biblioteca")},
        {QStringLiteral("Filesystem path"), QStringLiteral("Caminho no sistema")},
        {QStringLiteral("Create library"), QStringLiteral("Criar biblioteca")},
        {QStringLiteral("Delete"), QStringLiteral("Excluir")},
        {QStringLiteral("Delete library %1? Its items will leave the catalog."),
         QStringLiteral("Excluir biblioteca %1? Seus itens sairão do catálogo.")},
        {QStringLiteral("Change role of %1 to %2?"), QStringLiteral("Alterar função de %1 para %2?")},
        {QStringLiteral("Plugins"), QStringLiteral("Plugins")},
        {QStringLiteral("No plugins reported."), QStringLiteral("Nenhum plugin relatado.")},
        {QStringLiteral("Healthy"), QStringLiteral("Saudável")},
        {QStringLiteral("Unhealthy"), QStringLiteral("Não saudável")},
        {QStringLiteral("Maintenance"), QStringLiteral("Manutenção")},
        {QStringLiteral("Scan now"), QStringLiteral("Escanear agora")},
        {QStringLiteral("Download backup"), QStringLiteral("Baixar backup")},
        {QStringLiteral("Scan idle."), QStringLiteral("Escaneamento ocioso.")},
        {QStringLiteral("Playback"), QStringLiteral("Reprodução")},
        {QStringLiteral("Resume playback automatically"), QStringLiteral("Retomar reprodução automaticamente")},
        {QStringLiteral("Autoplay next episode"), QStringLiteral("Reproduzir próximo episódio automaticamente")},
        {QStringLiteral("Per-series autoplay"), QStringLiteral("Autoplay por série")},
        {QStringLiteral("On"), QStringLiteral("Ligado")},
        {QStringLiteral("Default"), QStringLiteral("Padrão")},
        {QStringLiteral("About"), QStringLiteral("Sobre")},
        {QStringLiteral("Lain desktop %1"), QStringLiteral("Lain desktop %1")},
        {QStringLiteral("Are you sure?"), QStringLiteral("Tem certeza?")},
        {QStringLiteral("Cancel"), QStringLiteral("Cancelar")},
        {QStringLiteral("Confirm"), QStringLiteral("Confirmar")},
        {QStringLiteral("Apply"), QStringLiteral("Aplicar")},
        {QStringLiteral("Tap a provider to select it:"), QStringLiteral("Toque em um provedor para selecioná-lo:")},
        {QStringLiteral("Change providers for %1? Playback, search, or metadata may be affected."),
         QStringLiteral("Alterar provedores de %1? Reprodução, busca ou metadados podem ser afetados.")},
        {QStringLiteral("Username required, password at least 8 characters."),
         QStringLiteral("Usuário obrigatório, senha com ao menos 8 caracteres.")},
        {QStringLiteral("Password must be at least 8 characters."),
         QStringLiteral("A senha deve ter ao menos 8 caracteres.")},
        {QStringLiteral("Library name and path are required."),
         QStringLiteral("Nome e caminho da biblioteca são obrigatórios.")},
        {QStringLiteral("Username and password are required."),
         QStringLiteral("Usuário e senha são obrigatórios.")},
        {QStringLiteral("1 queued update"), QStringLiteral("1 atualização na fila")},
        {QStringLiteral("%1 queued updates"), QStringLiteral("%1 atualizações na fila")},
        {QStringLiteral("Season %1"), QStringLiteral("Temporada %1")},
        {QStringLiteral("Specials"), QStringLiteral("Especiais")},
        {QStringLiteral("1 episode"), QStringLiteral("1 episódio")},
        {QStringLiteral("%1 episodes"), QStringLiteral("%1 episódios")},
        {QStringLiteral("1 season"), QStringLiteral("1 temporada")},
        {QStringLiteral("%1 seasons"), QStringLiteral("%1 temporadas")},
        {QStringLiteral("Unknown provisioning method."), QStringLiteral("Método de provisionamento desconhecido.")},
        {QStringLiteral("Port must be an integer between 1 and 65535."),
         QStringLiteral("A porta deve ser um inteiro entre 1 e 65535.")},
        {QStringLiteral("Could not create provisioning directories."),
         QStringLiteral("Não foi possível criar os diretórios de provisionamento.")},
        {QStringLiteral("Could not write the compose file."),
         QStringLiteral("Não foi possível gravar o arquivo compose.")},
        {QStringLiteral("Could not write the compose environment."),
         QStringLiteral("Não foi possível gravar o ambiente compose.")},
        {QStringLiteral("Starting the server container…"), QStringLiteral("Iniciando o contêiner do servidor…")},
        {QStringLiteral("Could not start the server container."),
         QStringLiteral("Não foi possível iniciar o contêiner do servidor.")},
        {QStringLiteral("Server container started on port %1."),
         QStringLiteral("Contêiner do servidor iniciado na porta %1.")},
        {QStringLiteral("Enabling the user service…"), QStringLiteral("Ativando o serviço de usuário…")},
        {QStringLiteral("Service reload failed."), QStringLiteral("Falha ao recarregar o serviço.")},
        {QStringLiteral("Could not start the user service."),
         QStringLiteral("Não foi possível iniciar o serviço de usuário.")},
        {QStringLiteral("User service started on port %1."),
         QStringLiteral("Serviço de usuário iniciado na porta %1.")},
        {QStringLiteral("Could not write the service unit."),
         QStringLiteral("Não foi possível gravar a unidade do serviço.")},
        {QStringLiteral("Downloading the server release…"), QStringLiteral("Baixando a versão do servidor…")},
        {QStringLiteral("Could not download the server release."),
         QStringLiteral("Não foi possível baixar a versão do servidor.")},
        {QStringLiteral("Could not write the server download."),
         QStringLiteral("Não foi possível gravar o download do servidor.")},
        {QStringLiteral("Could not unpack the server release."),
         QStringLiteral("Não foi possível descompactar a versão do servidor.")},
        {QStringLiteral("Could not install the server binary."),
         QStringLiteral("Não foi possível instalar o binário do servidor.")},
        {QStringLiteral("Server binary installed. Run it to start."),
         QStringLiteral("Binário do servidor instalado. Execute-o para iniciar.")},
        {QStringLiteral("Server started."), QStringLiteral("Servidor iniciado.")},
        {QStringLiteral("Could not start the server."), QStringLiteral("Não foi possível iniciar o servidor.")},
        {QStringLiteral("Server stopped."), QStringLiteral("Servidor parado.")},
        {QStringLiteral("Could not stop the server."), QStringLiteral("Não foi possível parar o servidor.")},
        {QStringLiteral("Binary installations run manually."),
         QStringLiteral("Instalações binárias são executadas manualmente.")},
        {QStringLiteral("Could not pull the server image."),
         QStringLiteral("Não foi possível baixar a imagem do servidor.")},
        {QStringLiteral("Could not restart the server."),
         QStringLiteral("Não foi possível reiniciar o servidor.")},
        {QStringLiteral("Server updated to %1."), QStringLiteral("Servidor atualizado para %1.")},
        {QStringLiteral("Could not restart the service."),
         QStringLiteral("Não foi possível reiniciar o serviço.")},
        {QStringLiteral("Installation removed. Data kept at %1."),
         QStringLiteral("Instalação removida. Dados mantidos em %1.")},
        {QStringLiteral("Could not stop the service."),
         QStringLiteral("Não foi possível parar o serviço.")},
        {QStringLiteral("Service removed. Data and binary kept."),
         QStringLiteral("Serviço removido. Dados e binário mantidos.")},
        {QStringLiteral("Binary removed from %1."), QStringLiteral("Binário removido de %1.")},
        {QStringLiteral("Only installations provisioned by this app can be managed."),
         QStringLiteral("Apenas instalações provisionadas por este app podem ser gerenciadas.")},
        {QStringLiteral("Choose an existing media directory first."),
         QStringLiteral("Escolha um diretório de mídia existente primeiro.")},
        {QStringLiteral("That location cannot be changed."), QStringLiteral("Esse local não pode ser alterado.")},
        {QStringLiteral("Permission change failed."), QStringLiteral("Falha na alteração de permissão.")},
        {QStringLiteral("Permissions fixed for %1."), QStringLiteral("Permissões corrigidas para %1.")},
        {QStringLiteral("Restarting the user service…"), QStringLiteral("Reiniciando o serviço de usuário…")},
        {QStringLiteral("Check for app updates"), QStringLiteral("Verificar atualizações do app")},
        {QStringLiteral("Update to %1"), QStringLiteral("Atualizar para %1")},
        {QStringLiteral("Checking for app updates…"), QStringLiteral("Verificando atualizações do app…")},
        {QStringLiteral("App update available: %1"), QStringLiteral("Atualização do app disponível: %1")},
        {QStringLiteral("App is up to date."), QStringLiteral("App atualizado.")},
        {QStringLiteral("Check for app updates first."), QStringLiteral("Verifique atualizações do app primeiro.")},
        {QStringLiteral("Downloading the app update…"), QStringLiteral("Baixando a atualização do app…")},
        {QStringLiteral("Could not download the app update."),
         QStringLiteral("Não foi possível baixar a atualização do app.")},
        {QStringLiteral("App update failed checksum verification."),
         QStringLiteral("A atualização falhou na verificação de checksum.")},
        {QStringLiteral("Could not write the app update."),
         QStringLiteral("Não foi possível gravar a atualização do app.")},
        {QStringLiteral("Could not install the app update."),
         QStringLiteral("Não foi possível instalar a atualização do app.")},
        {QStringLiteral("App updated to %1. Restart to use it."),
         QStringLiteral("App atualizado para %1. Reinicie para usar.")},
        {QStringLiteral("Composition changed elsewhere. Review and retry."),
         QStringLiteral("A composição mudou. Revise e tente de novo.")},
        {QStringLiteral("Providers updated for %1."), QStringLiteral("Provedores atualizados para %1.")},
        {QStringLiteral("Provision"), QStringLiteral("Provisionar")},
        {QStringLiteral("Port"), QStringLiteral("Porta")},
        {QStringLiteral("Choose…"), QStringLiteral("Escolher…")},
        {QStringLiteral("Default location"), QStringLiteral("Local padrão")},
        {QStringLiteral("Managed installation"), QStringLiteral("Instalação gerenciada")},
        {QStringLiteral("Uninstall"), QStringLiteral("Desinstalar")},
        {QStringLiteral("Media directory"), QStringLiteral("Diretório de mídia")},
        {QStringLiteral("Fix media permissions…"), QStringLiteral("Corrigir permissões de mídia…")},
        {QStringLiteral("Update available: %1"), QStringLiteral("Atualização disponível: %1")},
        {QStringLiteral("Uninstalling removes the server but keeps your data."),
         QStringLiteral("A desinstalação remove o servidor mas mantém seus dados.")},
    };
}
