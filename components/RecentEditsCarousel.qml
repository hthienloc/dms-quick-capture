import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var daemon: null
    property var entries: []
    property int previewIndex: -1

    readonly property var previewEntry: previewIndex >= 0 && previewIndex < entries.length ? entries[previewIndex] : null
    readonly property real heightFraction: previewIndex >= 0 ? 0.7 : 0.45
    property int currentPage: 0

    readonly property int itemsPerPage: 4
    readonly property int totalPages: Math.max(1, Math.ceil(entries.length / itemsPerPage))

    function clampPage() {
        if (currentPage >= totalPages) currentPage = totalPages - 1
        if (currentPage < 0) currentPage = 0
    }

    onEntriesChanged: clampPage()

    function refresh() {
        if (!root.daemon || !root.daemon.pluginData) return
        var dir = root.daemon.pluginData.saveDirectory || "~/Pictures/Screenshots"
        dir = String(dir).replace(/^~/, Quickshell.env("HOME"))
        var exts = ["png", "jpg", "jpeg", "webp"]
        var globs = exts.map(function(e) { return "\"" + dir + "\"/*." + e }).join(" ")
        var cmd = "for f in " + globs + "; do [ -f \"$f\" ] && echo \"$(stat -c '%Y' \"$f\" 2>/dev/null)|$f\"; done | sort -rn | head -50"
        Proc.runCommand("scan-history", ["sh", "-c", cmd], function(stdout) {
            var list = []
            var lines = stdout.trim().split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim()
                if (!line) continue
                var sep = line.indexOf("|")
                if (sep < 0) continue
                var ts = parseInt(line.substring(0, sep)) * 1000
                var path = line.substring(sep + 1)
                if (path) list.push({ timestamp: ts, savedPath: path, _glIdx: list.length })
            }
            root.entries = list
        })
    }

    onDaemonChanged: { if (root.daemon && root.daemon.pluginData) refresh() }

    Column {
        anchors.fill: parent
        spacing: 0

        // Header
        Item {
            width: parent.width
            height: 44

            DankActionButton {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                iconName: "arrow_back"
                iconSize: 16
                buttonSize: 32
                backgroundColor: "transparent"
                iconColor: Theme.surfaceText
                visible: root.previewIndex >= 0
                onClicked: root.previewIndex = -1
            }

            StyledText {
                anchors.centerIn: parent
                text: root.previewIndex >= 0 ? I18n.tr("Preview") : 
                     (root.daemon && root.daemon.pluginData ? root.daemon.pluginData.saveDirectory || "~/Pictures/Screenshots" : I18n.tr("Recent Edits"))
                font.pixelSize: Theme.fontSizeNormal
                font.bold: true
                color: Theme.surfaceText
            }
        }

        // Empty state
        StyledText {
            width: parent.width
            height: parent.height - 44
            visible: root.entries.length === 0
            text: I18n.tr("No saved images yet")
            font.pixelSize: Theme.fontSizeNormal
            color: Theme.surfaceVariantText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // Carousel
        Item {
            id: carouselView
            width: parent.width
            height: parent.height - 44
            visible: root.entries.length > 0 && root.previewIndex < 0

            readonly property real cardW: Math.max(60, (width - 46) / 4)

            Column {
                anchors.fill: parent
                spacing: 4

                Item {
                    width: parent.width
                    height: parent.height - 40
                    clip: true

                    Row {
                        spacing: 10
                        height: parent.height
                        x: -root.currentPage * root.itemsPerPage * (carouselView.cardW + 10)

                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Repeater {
                            model: root.entries

                            delegate: Item {
                                required property var modelData

                                width: carouselView.cardW
                                height: parent.height

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceContainerLow
                                    border.color: cardHover.hovered ? Theme.primary : "transparent"
                                    border.width: cardHover.hovered ? 2 : 0
                                    clip: true

                                    Behavior on border.color { ColorAnimation { duration: Theme.shorterDuration } }

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        source: "file://" + modelData.savedPath
                                        sourceSize.width: parent.width
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }
                                }

                                HoverHandler { id: cardHover }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.previewIndex = modelData._glIdx
                                }

                                property bool _copied: false

                                Timer {
                                    interval: 1500
                                    repeat: false
                                    running: parent._copied
                                    onTriggered: parent._copied = false
                                }

                                DankActionButton {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    z: 1
                                    iconName: "open_in_new"
                                    iconSize: 18
                                    buttonSize: 36
                                    radius: height / 2
                                    visible: cardHover.hovered
                                    tooltipText: I18n.tr("Open")
                                    onClicked: Proc.runCommand("open-card", ["xdg-open", modelData.savedPath])

                                    property bool _ovHovered: false
                                    backgroundColor: _ovHovered ? Qt.rgba(0.3, 0.3, 0.3, 0.8) : Qt.rgba(0, 0, 0, 0.55)
                                    iconColor: "white"
                                    scale: _ovHovered ? 1.15 : 1.0
                                    onEntered: _ovHovered = true
                                    onExited: _ovHovered = false
                                    Behavior on backgroundColor { ColorAnimation { duration: Theme.shorterDuration } }
                                    Behavior on scale { NumberAnimation { duration: Theme.shorterDuration } }
                                }

                                DankActionButton {
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    z: 1
                                    iconName: parent._copied ? "check" : "content_copy"
                                    iconSize: 18
                                    buttonSize: 36
                                    radius: height / 2
                                    visible: cardHover.hovered
                                    tooltipText: parent._copied ? I18n.tr("Copied") : I18n.tr("Copy")
                                    onClicked: {
                                        parent._copied = true
                                        DMSService.sendRequest("clipboard.copyFile", { "filePath": modelData.savedPath })
                                        ToastService.showInfo(I18n.tr("Image copied to clipboard"))
                                    }

                                    property bool _ovHovered: false
                                    backgroundColor: _ovHovered ? Qt.rgba(0.3, 0.3, 0.3, 0.8) : Qt.rgba(0, 0, 0, 0.55)
                                    iconColor: parent._copied ? "#4caf50" : "white"
                                    scale: _ovHovered ? 1.15 : 1.0
                                    onEntered: _ovHovered = true
                                    onExited: _ovHovered = false
                                    Behavior on backgroundColor { ColorAnimation { duration: Theme.shorterDuration } }
                                    Behavior on scale { NumberAnimation { duration: Theme.shorterDuration } }
                                }
                            }
                        }
                    }
                }

                // Page indicator
                Item {
                    width: parent.width
                    height: 36

                    DankButtonGroup {
                        anchors.centerIn: parent
                        visible: root.totalPages > 1
                        model: {
                            var pages = []
                            for (var i = 0; i < root.totalPages; i++) pages.push(String(i + 1))
                            return pages
                        }
                        currentIndex: root.currentPage
                        size: "small"
                        buttonHeight: 28
                        minButtonWidth: 36
                        onSelectionChanged: (index, selected) => {
                            if (selected) root.currentPage = index
                        }
                    }
                }
            }
        }

        // Preview
        Item {
            width: parent.width
            height: parent.height - 44
            visible: root.previewEntry

            onVisibleChanged: { if (!visible) _previewCopied = false }

            Image {
                anchors.fill: parent
                anchors.margins: 8
                anchors.bottomMargin: 56
                source: root.previewEntry ? "file://" + root.previewEntry.savedPath : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 1920
            }

            DankActionButton {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                iconName: "chevron_left"
                iconSize: 24
                buttonSize: 40
                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, 0.7)
                iconColor: Theme.surfaceText
                visible: root.previewIndex > 0
                onClicked: root.previewIndex--
            }

            DankActionButton {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                iconName: "chevron_right"
                iconSize: 24
                buttonSize: 40
                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, 0.7)
                iconColor: Theme.surfaceText
                visible: root.previewIndex < root.entries.length - 1
                onClicked: root.previewIndex++
            }

            property bool _previewCopied: false

            Timer {
                interval: 1500
                repeat: false
                running: parent._previewCopied
                onTriggered: parent._previewCopied = false
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 8

                DankButton {
                    iconName: "open_in_new"
                    text: I18n.tr("Open")
                    buttonHeight: 36
                    horizontalPadding: 16
                    backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, 0.9)
                    textColor: Theme.surfaceText
                    onClicked: {
                        if (root.previewEntry)
                            Proc.runCommand("open-preview", ["xdg-open", root.previewEntry.savedPath])
                    }
                }

                DankButton {
                    iconName: parent._previewCopied ? "check" : "content_copy"
                    text: parent._previewCopied ? I18n.tr("Copied") : I18n.tr("Copy")
                    buttonHeight: 36
                    horizontalPadding: 16
                    backgroundColor: parent._previewCopied
                        ? Qt.rgba(0.3, 0.7, 0.3, 0.9)
                        : Theme.withAlpha(Theme.primary, 0.9)
                    textColor: parent._previewCopied ? "white" : Theme.onPrimary
                    onClicked: {
                        if (root.previewEntry) {
                            parent._previewCopied = true
                            DMSService.sendRequest("clipboard.copyFile", { "filePath": root.previewEntry.savedPath })
                            ToastService.showInfo(I18n.tr("Image copied to clipboard"))
                        }
                    }
                }
            }

            DankActionButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                iconName: "delete"
                iconSize: 18
                buttonSize: 32
                radius: height / 2
                backgroundColor: Qt.rgba(1, 0, 0, 0.25)
                iconColor: "#ff6b6b"
                tooltipText: I18n.tr("Delete")
                onClicked: {
                    if (root.previewEntry) {
                        var delPath = root.previewEntry.savedPath
                        root.previewIndex = -1
                        Proc.runCommand("delete-preview", ["rm", "-f", delPath], function() {
                            root.refresh()
                        })
                    }
                }
            }
        }
    }
}
