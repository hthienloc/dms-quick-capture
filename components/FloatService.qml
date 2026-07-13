import QtQuick
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    property var openWindows: []
    property var floatyComponent: null
    property var pendingState: null

    signal restoreRequested(string imageSource)

    function ensureComponent() {
        if (!root.floatyComponent) {
            root.floatyComponent = Qt.createComponent(Qt.resolvedUrl("FloatWindow.qml"));
        }
        return root.floatyComponent;
    }

    function spawnWindow(imageSource, pluginData) {
        var component = root.ensureComponent();
        if (!component || component.status === Component.Error) {
            console.error("FloatService: failed to load FloatyWindow component", component ? component.errorString() : "null");
            return;
        }

        var createWin = function() {
            var win = component.createObject(root, {
                imageSource: imageSource,
                pluginData: pluginData || {},
                plugin: root
            });

            if (win !== null) {
                root.openWindows = [...root.openWindows, win];
                win.closing.connect(function() {
                    root.openWindows = root.openWindows.filter(function(w) { return w !== win; });
                });
            } else {
                ToastService.showError("Failed to create float window.");
            }
        };

        if (component.status === Component.Ready) {
            createWin();
        } else {
            component.statusChanged.connect(function() {
                if (component.status === Component.Ready) createWin();
            });
        }
    }

    function closeAllWindows() {
        var windows = [...root.openWindows];
        for (var i = 0; i < windows.length; i++) {
            if (windows[i] && typeof windows[i].close === "function") {
                windows[i].close();
            }
        }
    }

    function raiseWindow(win) {
        if (!win) return;
        for (var i = 0; i < root.openWindows.length; i++) {
            var w = root.openWindows[i];
            if (w && typeof w.isTop !== 'undefined') {
                w.isTop = (w === win);
            }
        }
    }

    function saveState(state) {
        root.pendingState = state;
    }

    function requestRestore(imageSource) {
        root.restoreRequested(imageSource);
    }
}
