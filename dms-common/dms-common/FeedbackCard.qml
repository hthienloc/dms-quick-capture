import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

SettingsCard {
    id: root
    property string repoUrl: ""

    SectionTitle { 
        text: I18n.tr("Feedback & Support")
        icon: "bug_report" 
    }

    Row {
        width: parent.width
        spacing: Theme.spacingM

        Image {
            source: "assets/author_logo.png"
            width: 64
            height: 64
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
            
            // Optional: make it look a bit nicer with a subtle shadow or rounding
            // if you want, but simple is often best for logos.
        }

        Column {
            width: parent.width - 64 - parent.spacing
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: I18n.tr("Found a bug or have a feature request? Please report it on the GitHub repository.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.Wrap
            }

            DankButton {
                text: I18n.tr("Open Repository")
                iconName: "open_in_new"
                backgroundColor: Theme.withAlpha(Theme.primary, 0.15)
                textColor: Theme.primary
                visible: root.repoUrl !== ""
                onClicked: {
                    Quickshell.execDetached(["gio", "open", root.repoUrl])
                }
            }
        }
    }
}
