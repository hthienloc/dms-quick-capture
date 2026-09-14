import QtQuick
import qs.Common
import qs.Widgets
import "../../dms-common"

StyledRect {
    id: root

    property alias title: header.text
    property alias icon: header.icon
    property bool resettable: true
    property alias collapsible: header.collapsible
    property alias expanded: header.isExpanded
    property alias stateKey: header.settingKey
    default property alias content: body.data
    readonly property bool isDirty: body.isDirty

    width: parent.width
    height: column.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainer

    function resetToDefault() {
        body.resetToDefault();
    }

    function loadValue() {
        body.loadValue();
    }

    Column {
        id: column
        width: parent.width - Theme.spacingL * 2
        anchors.centerIn: parent
        spacing: Theme.spacingM

        SectionTitle {
            id: header
            showReset: root.resettable && body.isDirty
            onResetClicked: body.resetToDefault()
        }

        SettingsGroup {
            id: body
            visible: header.isExpanded
        }
    }
}
