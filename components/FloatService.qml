import QtQuick
import Quickshell
import qs.Common
import qs.Services

Item {
    id: root

    property var openWindows: []
    property var floatyComponent: null

    signal restoreRequested(string imageSource, var annotationState)

    function ensureComponent() {
        if (!root.floatyComponent) {
            root.floatyComponent = Qt.createComponent(Qt.resolvedUrl("FloatWindow.qml"));
        }
        return root.floatyComponent;
    }

    function spawnWindow(imageSource, pluginData, annotationState, tempPaths) {
        var component = root.ensureComponent();
        if (!component || component.status === Component.Error) {
            console.error("FloatService: failed to load FloatWindow component", component ? component.errorString() : "null");
            return;
        }

        var createWin = function() {
            var win = component.createObject(root, {
                imageSource: imageSource,
                pluginData: pluginData || {},
                plugin: root,
                annotationState: annotationState || null,
                tempPaths: tempPaths || []
            });

            if (win !== null) {
                root.openWindows = [...root.openWindows, win];
                win.closing.connect(function() {
                    root.openWindows = root.openWindows.filter(function(w) { return w !== win; });
                    for (var i = 0; i < (tempPaths || []).length; i++) {
                        var tp = tempPaths[i];
                        if (tp && tp.indexOf("/tmp/dms_capture_") >= 0) {
                            Proc.runCommand("float-delayed-cleanup-" + i, ["sh", "-c", "sleep 5 && rm -f -- '" + tp + "'"]);
                        }
                    }
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

    function requestRestore(imageSource) {
        for (var i = 0; i < root.openWindows.length; i++) {
            if (root.openWindows[i].imageSource === imageSource) {
                root.restoreRequested(imageSource, root.openWindows[i].annotationState);
                return;
            }
        }
        root.restoreRequested(imageSource, null);
    }
}
