import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    required property QtObject config
    property string watermarkType: "text"
    property string position: "bottom_right"
    property real opacityPercent: 20
    property string text: ""
    property real textSizePercent: 5
    property string imagePath: ""
    property real imageSizePercent: 5

    readonly property real margin: Theme.spacingL
    readonly property bool showsImage: watermarkType === "image" || watermarkType === "hybrid"
    readonly property bool showsText: watermarkType === "text" || watermarkType === "hybrid"

    width: parent.width
    height: 160
    radius: Theme.cornerRadius / 2
    color: Theme.surfaceContainer
    clip: true

    function alignedX(itemWidth) {
        if (position.endsWith("left") || position === "left")
            return margin;
        if (position.endsWith("right") || position === "right")
            return width - itemWidth - margin;
        return (width - itemWidth) / 2;
    }

    function alignedY(itemHeight) {
        if (position.startsWith("top"))
            return margin;
        if (position.startsWith("bottom"))
            return height - itemHeight - margin;
        return (height - itemHeight) / 2;
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Theme.surfaceContainerHighest
            }
            GradientStop {
                position: 1.0
                color: Theme.surfaceContainerLowest
            }
        }
    }

    Image {
        id: imageLoader
        property int pathIndex: 0
        property var fallbackPaths: []

        source: {
            if (root.imagePath) {
                const p = Paths.expandTilde(root.imagePath.trim());
                return p.indexOf("/") === 0 ? Paths.toFileUrl(p) : p;
            }
            return pathIndex < fallbackPaths.length ? fallbackPaths[pathIndex] : "";
        }
        onStatusChanged: {
            if (status === Image.Error && !root.imagePath && pathIndex < fallbackPaths.length - 1)
                Qt.callLater(() => pathIndex++);
        }
        Component.onCompleted: {
            const username = Quickshell.env("USER") || Quickshell.env("USERNAME") || "";
            const home = Paths.strip(Paths.home);
            const list = [];
            if (home)
                list.push("file://" + home + "/.face", "file://" + home + "/.face.icon");
            if (username)
                list.push("file:///var/lib/AccountsService/icons/" + username);
            list.push("image://icon/user-info", "image://icon/avatar-default");
            fallbackPaths = list;
        }
        visible: false
        cache: true
    }

    Row {
        id: watermark
        x: root.alignedX(width)
        y: root.alignedY(height)
        spacing: Math.round(previewText.font.pixelSize * 0.4)
        opacity: root.opacityPercent / 100

        Image {
            visible: root.showsImage && imageLoader.status === Image.Ready
            source: imageLoader.source
            readonly property real scaleFactor: {
                if (imageLoader.status !== Image.Ready)
                    return 0;
                const maxW = root.width * (root.imageSizePercent / 100);
                const maxH = root.height * (root.imageSizePercent / 100);
                return Math.min(maxW / imageLoader.sourceSize.width, maxH / imageLoader.sourceSize.height, 1.0);
            }
            height: imageLoader.sourceSize.height * scaleFactor
            width: imageLoader.sourceSize.width * scaleFactor
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: root.showsImage && imageLoader.status !== Image.Ready
            text: root.imagePath ? I18n.trFor("quickCapture", "Image Error") : I18n.trFor("quickCapture", "No Image Specified")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
            font.italic: true
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            id: previewText
            visible: root.showsText
            text: root.config.formatWatermarkText(root.text || "© {user}")
            font.pixelSize: Math.max(10, Math.round(root.height * (root.textSizePercent / 100)))
            font.weight: Font.Bold
            color: "#ffffff"
            style: Text.Outline
            styleColor: "#000000"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
