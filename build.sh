#!/usr/bin/bash
# ==============================================================================
# Script de build et de test local pour JClic.js (Fedora / Arrera / Copr)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"
PKG_NAME="jclic"
PKG_VERSION="2.3.4"
RPMBUILD_DIR="/tmp/rpmbuild"
STAGE_DIR="/tmp/${PKG_NAME}-build-stage"
TARBALL="${RPMBUILD_DIR}/SOURCES/${PKG_NAME}-${PKG_VERSION}.tar.gz"
OUTPUT_DIR="${ROOT_DIR}/rpm"

# Couleurs pour le terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

# ------------------------------------------------------------------------------
# 1. Vérification et récupération de jclic.min.js
# ------------------------------------------------------------------------------
prepare_bundle() {
    print_info "Vérification du bundle JavaScript (jclic.min.js)..."

    mkdir -p "${ROOT_DIR}/dist"

    if [ -f "${ROOT_DIR}/dist/jclic.min.js" ]; then
        print_success "Bundle jclic.min.js trouvé dans dist/."
        cp -a "${ROOT_DIR}/dist/jclic.min.js"* "${ROOT_DIR}/packaging/" 2>/dev/null || :
        return 0
    fi

    if [ -f "${ROOT_DIR}/packaging/jclic.min.js" ]; then
        print_success "Bundle jclic.min.js trouvé dans packaging/."
        return 0
    fi

    # Si node et npm sont disponibles, on essaie de compiler
    if command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
        print_info "Node.js et npm détectés. Compilation locale avec Vite..."
        (cd "${ROOT_DIR}" && npm run build-browser)
        if [ -f "${ROOT_DIR}/dist/jclic.min.js" ]; then
            print_success "Compilation Vite terminée avec succès !"
            cp -a "${ROOT_DIR}/dist/jclic.min.js"* "${ROOT_DIR}/packaging/" 2>/dev/null || :
            return 0
        fi
    fi

    # Sinon, on tente de télécharger le bundle officiel de la version 2.3.4
    print_info "Tentative de récupération du bundle officiel 2.3.4 depuis le CDN..."
    CDN_URL="https://cdn.jsdelivr.net/npm/jclic@${PKG_VERSION}/dist/jclic.min.js"
    if command -v curl >/dev/null 2>&1; then
        if curl -sLf "${CDN_URL}" -o "${ROOT_DIR}/packaging/jclic.min.js"; then
            print_success "Bundle jclic.min.js téléchargé avec succès depuis jsDelivr !"
            cp -a "${ROOT_DIR}/packaging/jclic.min.js" "${ROOT_DIR}/dist/" 2>/dev/null || :
            return 0
        fi
    fi

    print_warn "Impossible de télécharger ou compiler jclic.min.js actuellement."
    print_warn "Un placeholder sera utilisé. Vous pourrez lancer 'npm run build' ou télécharger le bundle plus tard."
    echo "// jclic.min.js placeholder" > "${ROOT_DIR}/packaging/jclic.min.js"
}

# ------------------------------------------------------------------------------
# 2. Construction du RPM et du SRPM
# ------------------------------------------------------------------------------
build_rpm() {
    prepare_bundle

    print_info "Préparation de l'environnement rpmbuild..."
    mkdir -p "${RPMBUILD_DIR}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
    rm -rf "${STAGE_DIR}"
    mkdir -p "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/"{bin,desktop,icons,demo}

    print_info "Assemblage des fichiers sources..."
    cp -a "${ROOT_DIR}/packaging/bin/"* "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/bin/"
    cp -a "${ROOT_DIR}/packaging/desktop/"* "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/desktop/"
    cp -a "${ROOT_DIR}/packaging/icons/"* "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/icons/"
    cp -a "${ROOT_DIR}/packaging/index.html" "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/"
    cp -a "${ROOT_DIR}/test/icon-192.png" "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/"
    cp -a "${ROOT_DIR}/LICENSE.txt" "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/"
    cp -a "${ROOT_DIR}/README.md" "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/"
    cp -a "${ROOT_DIR}/test/jclic-demo/demo.jclic.zip" "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/demo/"
    if [ -f "${ROOT_DIR}/packaging/jclic.min.js" ]; then
        cp -a "${ROOT_DIR}/packaging/jclic.min.js"* "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/"
    elif [ -f "${ROOT_DIR}/dist/jclic.min.js" ]; then
        cp -a "${ROOT_DIR}/dist/jclic.min.js"* "${STAGE_DIR}/${PKG_NAME}-${PKG_VERSION}/"
    fi

    print_info "Création de l'archive tarball source : ${PKG_NAME}-${PKG_VERSION}.tar.gz..."
    tar -czf "${TARBALL}" -C "${STAGE_DIR}" "${PKG_NAME}-${PKG_VERSION}"

    cp "${ROOT_DIR}/packaging/jclic.spec" "${RPMBUILD_DIR}/SPECS/"

    print_info "Lancement de rpmbuild..."
    rpmbuild --define "_topdir ${RPMBUILD_DIR}" --define "_tmppath /tmp" -ba "${RPMBUILD_DIR}/SPECS/jclic.spec"

    print_info "Copie des paquets générés vers le dossier du projet (${OUTPUT_DIR})..."
    mkdir -p "${OUTPUT_DIR}"
    cp -f "${RPMBUILD_DIR}/RPMS/noarch/${PKG_NAME}-${PKG_VERSION}-"*.rpm "${OUTPUT_DIR}/"
    cp -f "${RPMBUILD_DIR}/SRPMS/${PKG_NAME}-${PKG_VERSION}-"*.src.rpm "${OUTPUT_DIR}/"

    echo ""
    print_success "=== Compilation terminée ! Les paquets sont dans ./rpm/ ==="
    echo ""
    echo -e "${GREEN}Paquet binaire RPM :${NC}"
    ls -lh "${OUTPUT_DIR}/${PKG_NAME}-${PKG_VERSION}-"*.rpm
    echo ""
    echo -e "${GREEN}Paquet source SRPM (pour Copr) :${NC}"
    ls -lh "${OUTPUT_DIR}/${PKG_NAME}-${PKG_VERSION}-"*.src.rpm
    echo ""
}

# ------------------------------------------------------------------------------
# 3. Test local dans Firefox (Profil WebApp sans onglets + avec barre de titre)
# ------------------------------------------------------------------------------
test_webapp() {
    print_info "Démarrage du test local dans Firefox (mode WebApp)..."

    TEST_PROFILE="/tmp/jclic-test-profile"
    rm -rf "${TEST_PROFILE}"
    mkdir -p "${TEST_PROFILE}/chrome"

    # Configuration du profil Firefox : pas d'onglets, barre de titre native avec bouton fermer
    cat << 'EOF' > "${TEST_PROFILE}/user.js"
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.tabs.inTitlebar", 0);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.page", 0);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("security.fileuri.strict_origin_policy", false);
EOF

    cat << 'EOF' > "${TEST_PROFILE}/chrome/userChrome.css"
#nav-bar,
#identity-box,
#TabsToolbar {
    visibility: collapse !important;
}
EOF

    LOCAL_URL="file://${ROOT_DIR}/packaging/index.html"

    export MOZ_APP_REMOTINGNAME="WebApp-jclic"
    export MOZ_WAYLAND_APP_ID="WebApp-jclic"
    export XAPP_FORCE_GTKWINDOW_ICON="${ROOT_DIR}/packaging/icons/jclic.png"

    print_info "Lancement de Firefox avec l'URL : ${LOCAL_URL}"
    firefox --class "WebApp-jclic" --name "WebApp-jclic" --profile "${TEST_PROFILE}" --no-remote "${LOCAL_URL}" &
    print_success "Firefox a été lancé en tâche de fond pour le test."
}

# ------------------------------------------------------------------------------
# 4. Installation locale avec DNF
# ------------------------------------------------------------------------------
install_rpm() {
    RPM_FILE=$(ls -t "${OUTPUT_DIR}/${PKG_NAME}-${PKG_VERSION}-"*.noarch.rpm "${RPMBUILD_DIR}/RPMS/noarch/${PKG_NAME}-${PKG_VERSION}-"*.rpm 2>/dev/null | head -n 1)
    if [ -z "${RPM_FILE}" ] || [ ! -f "${RPM_FILE}" ]; then
        print_warn "Aucun RPM compilé trouvé. Lancement préalable du build..."
        build_rpm
        RPM_FILE=$(ls -t "${OUTPUT_DIR}/${PKG_NAME}-${PKG_VERSION}-"*.noarch.rpm 2>/dev/null | head -n 1)
    fi

    print_info "Installation locale du paquet : ${RPM_FILE}..."
    sudo dnf install -y --nogpgcheck "${RPM_FILE}"
    print_success "Paquet installé avec succès !"

    print_info "Initialisation de l'intégration WebApp Manager..."
    if command -v jclic-webapp-init >/dev/null 2>&1; then
        jclic-webapp-init
        print_success "Raccourci WebApp Manager initialisé dans ~/.local/share/applications/ !"
    fi
}

# ------------------------------------------------------------------------------
# 5. Envoi vers Fedora Copr
# ------------------------------------------------------------------------------
push_copr() {
    SRPM_FILE=$(ls -t "${OUTPUT_DIR}/${PKG_NAME}-${PKG_VERSION}-"*.src.rpm "${RPMBUILD_DIR}/SRPMS/${PKG_NAME}-${PKG_VERSION}-"*.src.rpm 2>/dev/null | head -n 1)
    if [ -z "${SRPM_FILE}" ] || [ ! -f "${SRPM_FILE}" ]; then
        print_warn "Aucun SRPM trouvé. Lancement préalable du build..."
        build_rpm
        SRPM_FILE=$(ls -t "${OUTPUT_DIR}/${PKG_NAME}-${PKG_VERSION}-"*.src.rpm 2>/dev/null | head -n 1)
    fi

    print_info "Envoi vers Fedora Copr (projet education-suite)..."
    copr-cli build education-suite "${SRPM_FILE}"
    print_success "Build Copr soumis avec succès !"
}

# ------------------------------------------------------------------------------
# Point d'entrée principal
# ------------------------------------------------------------------------------
case "$1" in
    test|--test)
        test_webapp
        ;;
    install|--install)
        install_rpm
        ;;
    copr|--copr)
        push_copr
        ;;
    help|--help|-h)
        echo "Usage: $0 [COMMANDE]"
        echo ""
        echo "Commandes disponibles :"
        echo "  (sans argument) : Compile le RPM et le SRPM dans /tmp/rpmbuild"
        echo "  test            : Teste l'application dans Firefox (sans onglets, barre native)"
        echo "  install         : Installe le paquet RPM localement sur votre système (sudo dnf)"
        echo "  copr            : Publie le SRPM sur votre dépôt Copr (education-suite)"
        echo "  help            : Affiche cette aide"
        ;;
    *)
        build_rpm
        echo -e "${YELLOW}Prochaines étapes recommandées :${NC}"
        echo "  1. Tester l'affichage dans Firefox :  ./build.sh test"
        echo "  2. Installer le RPM localement :     ./build.sh install"
        echo "  3. Publier sur votre dépôt Copr :    ./build.sh copr"
        ;;
esac
