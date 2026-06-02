import QtQuick

Item {
    id: root
    
    // The parent popout to listen for 'opened' signal.
    property var parentPopout: null

    // Target to focus when opened.
    property Item target: null
    
    // Custom signal emitted when the popout opens
    signal opened()
    
    // Direct shortcut actions for common keys
    property var onSpacePressed: null
    property var onRPressed: null
    property var onEnterPressed: null
    property var onEscapePressed: null
    
    // Generic shortcuts list: [{ sequence: "Ctrl+S", action: () => ... }]
    property var customShortcuts: []

    Connections {
        target: parentPopout
        ignoreUnknownSignals: true
        function onOpened() {
            Qt.callLater(() => {
                if (root.target) {
                    root.target.forceActiveFocus();
                }
                root.opened();
            });
        }
    }

    Shortcut {
        sequence: "Space"
        enabled: root.onSpacePressed !== null
        onActivated: root.onSpacePressed()
    }

    Shortcut {
        sequence: "R"
        enabled: root.onRPressed !== null
        onActivated: root.onRPressed()
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: root.onEnterPressed !== null
        onActivated: root.onEnterPressed()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.onEscapePressed !== null
        onActivated: root.onEscapePressed()
    }

    Repeater {
        model: root.customShortcuts
        delegate: Shortcut {
            sequence: modelData.sequence
            onActivated: modelData.action()
        }
    }
}
