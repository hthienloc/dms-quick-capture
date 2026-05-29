import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

// PluginAbout.qml
// All-in-one About section: header, GitHub link, and contributors list.
// Usage:
//   PluginAbout {
//       pluginName: "My Plugin"
//       pluginIcon: "extension"
//       repoUrl:    "https://github.com/hthienloc/dms-my-plugin"
//   }
SettingsCard {
    id: root

    property string repoUrl: ""

    property var _contributors: []
    property bool _loading: false

    function _fetchContributors() {
        if (repoUrl === "" || _loading) return;
        let path = repoUrl.replace("https://github.com/", "");
        if (path.endsWith("/")) path = path.slice(0, -1);
        let xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    let data = JSON.parse(xhr.responseText);
                    root._contributors = data.map(u => ({
                        name:   u.login,
                        avatar: u.avatar_url,
                        url:    u.html_url
                    }));
                } catch (e) {
                    console.error("[PluginAbout] parse error:", e);
                }
            }
            root._loading = false;
        };
        root._loading = true;
        xhr.open("GET", "https://api.github.com/repos/" + path + "/contributors");
        xhr.send();
    }

    Component.onCompleted: _fetchContributors()
    onRepoUrlChanged:      _fetchContributors()

    // ── Header ─────────────────────────────────────────────────────────────
    SectionTitle {
        text: I18n.tr("Contributing")
        icon: "handshake"
    }

    // ── GitHub link ─────────────────────────────────────────────────────────
    Row {
        width: parent.width
        spacing: Theme.spacingM
        visible: root.repoUrl !== ""

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - githubBtn.width - parent.spacing
            spacing: 2

            StyledText {
                text: I18n.tr("Help us improve")
                font.bold: true
                font.pixelSize: Theme.fontSizeSmall
            }
            StyledText {
                width: parent.width
                text: I18n.tr("Found a bug, want to translate, or have a feature request? Join us on GitHub.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.Wrap
            }
        }

        DankButton {
            id: githubBtn
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("GitHub")
            iconName: "code"
            backgroundColor: Theme.withAlpha(Theme.primary, 0.1)
            textColor: Theme.primary
            onClicked: Quickshell.execDetached(["gio", "open", root.repoUrl])
        }
    }

    // ── Contributors ────────────────────────────────────────────────────────
    SectionTitle {
        text: I18n.tr("Contributors")
        icon: "groups"
    }

    StyledText {
        text: I18n.tr("Loading contributors...")
        visible: root._loading && root._contributors.length === 0
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingL
        visible: !root._loading || root._contributors.length > 0

        Repeater {
            model: root._contributors
            delegate: Row {
                spacing: Theme.spacingS
                height: 32

                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: Theme.surfaceContainerHigh
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        source: modelData.avatar
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                StyledText {
                    text: modelData.name
                    font.bold: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
