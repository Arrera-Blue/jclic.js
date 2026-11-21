Name:           jclic
Version:        2.3.4
Release:        1%{?dist}
Summary:        Lecteur d'activités éducatives multimédias JClic (HTML5)

License:        EUPL-1.2
URL:            https://github.com/Arrera-Blue/jclic.js
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  desktop-file-utils
Requires:       bash
Requires:       firefox

%description
JClic.js est un lecteur moderne HTML5 pour les activités éducatives interactives
JClic (associations, puzzles, mots croisés, texte).
Il fonctionne sous forme d'application web autonome intégrée dans Firefox via
un profil dédié sans barres de navigation, avec la barre de fenêtre native.

%prep
%autosetup

%build
# Application web HTML5/JS (aucun binaire à compiler lors du rpmbuild)

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/%{name}
mkdir -p %{buildroot}%{_datadir}/%{name}/demo
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/pixmaps
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/192x192/apps
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/scalable/apps
mkdir -p %{buildroot}%{_sysconfdir}/skel/.local/share/applications
mkdir -p %{buildroot}%{_sysconfdir}/xdg/autostart

# Installation des ressources de l'application
cp -a index.html jclic.min.js* icon-192.png %{buildroot}%{_datadir}/%{name}/
cp -a demo/* %{buildroot}%{_datadir}/%{name}/demo/

# Scripts de lancement et d'initialisation
install -m 0755 bin/jclic %{buildroot}%{_bindir}/jclic
install -m 0755 bin/jclic-webapp-init %{buildroot}%{_bindir}/jclic-webapp-init

# Icônes
install -m 0644 icons/jclic.png %{buildroot}%{_datadir}/pixmaps/%{name}.png
install -m 0644 icons/jclic.png %{buildroot}%{_datadir}/icons/hicolor/192x192/apps/%{name}.png
install -m 0644 icons/jclic.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/%{name}.svg

# Fichiers .desktop
desktop-file-install --dir=%{buildroot}%{_datadir}/applications desktop/webapp-jclic.desktop
install -m 0644 desktop/webapp-jclic.desktop %{buildroot}%{_sysconfdir}/skel/.local/share/applications/webapp-jclic.desktop
desktop-file-install --dir=%{buildroot}%{_sysconfdir}/xdg/autostart desktop/jclic-webapp-init.desktop

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/webapp-jclic.desktop
desktop-file-validate %{buildroot}%{_sysconfdir}/xdg/autostart/jclic-webapp-init.desktop

%files
%license LICENSE.txt
%doc README.md
%{_bindir}/jclic
%{_bindir}/jclic-webapp-init
%{_datadir}/%{name}
%{_datadir}/applications/webapp-jclic.desktop
%{_sysconfdir}/skel/.local/share/applications/webapp-jclic.desktop
%{_sysconfdir}/xdg/autostart/jclic-webapp-init.desktop
%{_datadir}/pixmaps/%{name}.png
%{_datadir}/icons/hicolor/192x192/apps/%{name}.png
%{_datadir}/icons/hicolor/scalable/apps/%{name}.svg

%changelog
* Sat Nov 21 2026 Baptiste <votre-email@exemple.com> - 2.3.4-1
- Paquet initial Fedora / Copr pour JClic.js avec intégration WebApp Manager et profil Firefox
