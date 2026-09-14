import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property string title: ""
    property bool divider: false

    readonly property bool isDirty: {
        const rows = collectRows(root);
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].isDirty === true)
                return true;
        }
        return false;
    }

    width: parent.width
    spacing: Theme.spacingM

    function collectRows(item) {
        const rows = [];
        const kids = item.children;
        for (let i = 0; i < kids.length; i++) {
            const child = kids[i];
            if (child.isDirty !== undefined) {
                rows.push(child);
                continue;
            }
            if (child.children !== undefined && child.children.length > 0)
                rows.push(...collectRows(child));
        }
        return rows;
    }

    function resetToDefault() {
        const rows = collectRows(root);
        for (let i = 0; i < rows.length; i++) {
            if (typeof rows[i].resetToDefault === "function")
                rows[i].resetToDefault();
        }
    }

    function loadValue() {
        const rows = collectRows(root);
        for (let i = 0; i < rows.length; i++) {
            if (typeof rows[i].loadValue === "function")
                rows[i].loadValue();
        }
    }

    Rectangle {
        visible: root.divider
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.2
    }

    StyledText {
        visible: root.title !== ""
        text: root.title
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.primary
    }
}
