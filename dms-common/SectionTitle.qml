import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root
    width: parent.width
    height: 32

    property alias text: titleText.text
    property string icon: ""

    property bool showReset: false
    signal resetClicked()
    signal clicked() // Tín hiệu mới cho hành động nhấn vào tiêu đề

    property bool hoverEnabled: false
    readonly property bool isHovered: hoverArea.containsMouse
    property color titleColor: (hoverEnabled && isHovered) ? Theme.primary : Theme.surfaceText

    property bool collapsible: false
    property bool isExpanded: true
    property string settingKey: ""

    property bool _isInitialized: false

    function _loadPersistence() {
        if (settingKey === "") return;
        const settings = _findSettings();
        if (settings && settings.pluginService) {
            isExpanded = settings.loadValue(settingKey, true);
            _isInitialized = true;
        }
    }

    onIsExpandedChanged: {
        if (settingKey === "" || !_isInitialized) return;
        const settings = _findSettings();
        if (settings) {
            settings.saveValue(settingKey, isExpanded);
        }
    }

    Component.onCompleted: {
        Qt.callLater(_loadPersistence);
    }

    function _findSettings() {
        let item = parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) {
                return item;
            }
            item = item.parent;
        }
        return null;
    }

    Row {
        id: titleRow
        anchors.centerIn: parent
        spacing: Theme.spacingS
        width: Math.min(implicitWidth, parent.width - 100)

        DankIcon {
            name: root.icon
            size: 18
            color: root.titleColor
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Appearance.anim.durations.quick } }
        }

        StyledText {
            id: titleText
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: root.titleColor
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            Behavior on color { ColorAnimation { duration: Appearance.anim.durations.quick } }
        }

        DankIcon {
            name: root.isExpanded ? "expand_less" : "expand_more"
            size: 16
            color: Theme.surfaceVariantText
            visible: root.collapsible
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: root.hoverEnabled || root.collapsible
        cursorShape: (root.collapsible || root.hoverEnabled) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.collapsible) {
                root.isExpanded = !root.isExpanded;
            }
            root.clicked(); // Phát tín hiệu khi người dùng nhấn
        }
    }

    Item {
        id: resetButton
        width: 32
        height: 32
        visible: root.showReset
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: resetArea.containsMouse ? Theme.primaryHoverLight : "transparent"
        }

        DankIcon {
            name: "restart_alt"
            size: 18
            color: Theme.primary
            anchors.centerIn: parent
            opacity: root.showReset ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Appearance.anim.durations.quick } }
        }

        MouseArea {
            id: resetArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                console.log(`[SectionTitle] Reset button clicked for: ${root.text}`);
                root.resetClicked();
            }
        }
    }
}
