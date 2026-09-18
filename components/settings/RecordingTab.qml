import QtQuick
import qs.Common
import "../../dms-common"
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null
    property var daemon: null

    readonly property bool gpuBackend: recordingBackend.value !== "wf-recorder"
    readonly property var fallbackInputs: [
        {
            label: I18n.trFor("quickCapture", "Default Microphone"),
            value: "default_input"
        }
    ]
    readonly property var fallbackOutputs: [
        {
            label: I18n.trFor("quickCapture", "Default Output"),
            value: "default_output"
        }
    ]

    Component.onCompleted: {
        if (daemon)
            daemon.refreshAudioDevices();
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "Video")
        icon: "videocam"

        StringSettingPlus {
            settingKey: "recordingDirectory"
            label: I18n.trFor("quickCapture", "Recording Folder")
            placeholder: Defaults.values.recordingDirectory
            defaultValue: Defaults.values.recordingDirectory
            isDirectory: true
        }

        Separator {}

        SelectionSettingPlus {
            id: recordingBackend
            settingKey: "recordingBackend"
            label: I18n.trFor("quickCapture", "Recording Backend")
            description: I18n.trFor("quickCapture", "Select screen recording backend. Auto attempts GPU first and falls back to CPU (%1).").arg("wf-recorder")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Auto"),
                    value: "auto"
                },
                {
                    label: "GPU Screen Recorder (NVENC / VA-API)",
                    value: "gpu-screen-recorder"
                },
                {
                    label: "wf-recorder (CPU libx264)",
                    value: "wf-recorder"
                }
            ]
            defaultValue: Defaults.values.recordingBackend
        }

        Separator {}

        SelectionSettingPlus {
            settingKey: "recordingScreenTarget"
            label: I18n.trFor("quickCapture", "Fullscreen Target")
            description: I18n.trFor("quickCapture", "Choose which monitor to capture during full screen recording.")
            options: root.config.screenOptions([
                {
                    label: I18n.trFor("quickCapture", "Primary Screen"),
                    value: "screen"
                },
                {
                    label: I18n.trFor("quickCapture", "Focused Screen"),
                    value: "focused"
                }
            ])
            defaultValue: Defaults.values.recordingScreenTarget
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: recordingFormat
            settingKey: "recordingFormat"
            label: I18n.trFor("quickCapture", "Container Format")
            options: [
                {
                    label: "MP4",
                    value: "mp4"
                },
                {
                    label: "MKV",
                    value: "mkv"
                },
                {
                    label: "WebM",
                    value: "webm"
                },
                {
                    label: "FLV",
                    value: "flv"
                },
                {
                    label: "GIF",
                    value: "gif"
                }
            ]
            defaultValue: Defaults.values.recordingFormat
        }

        SettingsGroup {
            visible: recordingFormat.value === "gif"

            Separator {}

            ButtonGroupSettingPlus {
                settingKey: "recordingGifFramerate"
                label: I18n.trFor("quickCapture", "GIF Framerate")
                options: [
                    {
                        label: "10 FPS",
                        value: "10"
                    },
                    {
                        label: "15 FPS",
                        value: "15"
                    },
                    {
                        label: "24 FPS",
                        value: "24"
                    },
                    {
                        label: "30 FPS",
                        value: "30"
                    }
                ]
                defaultValue: Defaults.values.recordingGifFramerate
            }
        }

        Separator {}

        ButtonGroupSettingPlus {
            settingKey: "recordingFramerate"
            label: I18n.trFor("quickCapture", "Framerate")
            options: [
                {
                    label: "30 FPS",
                    value: "30"
                },
                {
                    label: "60 FPS",
                    value: "60"
                },
                {
                    label: "120 FPS",
                    value: "120"
                }
            ]
            defaultValue: Defaults.values.recordingFramerate
        }

        Separator {}

        SelectionSettingPlus {
            settingKey: "recordingQuality"
            label: I18n.trFor("quickCapture", "Quality")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Very High"),
                    value: "very_high"
                },
                {
                    label: I18n.trFor("quickCapture", "High"),
                    value: "high"
                },
                {
                    label: I18n.trFor("quickCapture", "Medium"),
                    value: "medium"
                },
                {
                    label: I18n.trFor("quickCapture", "Low"),
                    value: "low"
                }
            ]
            defaultValue: Defaults.values.recordingQuality
        }

        Separator {}

        SelectionSettingPlus {
            settingKey: "recordingCodec"
            label: I18n.trFor("quickCapture", "Video Codec")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Auto"),
                    value: "auto"
                },
                {
                    label: "H.264",
                    value: "h264"
                },
                {
                    label: "HEVC (H.265)",
                    value: "hevc"
                },
                {
                    label: "AV1",
                    value: "av1"
                },
                {
                    label: "VP8",
                    value: "vp8"
                },
                {
                    label: "VP9",
                    value: "vp9"
                }
            ]
            defaultValue: Defaults.values.recordingCodec
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "recordCursor"
            label: I18n.trFor("quickCapture", "Include Cursor")
            defaultValue: Defaults.values.recordCursor
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "recordingSkipConfirm"
            label: I18n.trFor("quickCapture", "Skip confirmation")
            defaultValue: Defaults.values.recordingSkipConfirm
        }
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "Audio & Overlay")
        icon: "graphic_eq"

        InfoText {
            visible: !root.gpuBackend
            text: I18n.trFor("quickCapture", "Audio recording is disabled when using the %1 backend.").arg("wf-recorder (CPU)")
        }

        SettingsGroup {
            visible: root.gpuBackend

            ToggleSettingPlus {
                id: recordSystemAudio
                settingKey: "recordSystemAudio"
                label: I18n.trFor("quickCapture", "Record System Audio")
                defaultValue: Defaults.values.recordSystemAudio
            }

            SelectionSettingPlus {
                visible: recordSystemAudio.value
                settingKey: "systemAudioDevice"
                label: I18n.trFor("quickCapture", "System Audio Device")
                options: root.daemon?.audioOutputsList ?? root.fallbackOutputs
                defaultValue: Defaults.values.systemAudioDevice
            }

            Separator {}

            ToggleSettingPlus {
                id: recordMic
                settingKey: "recordMic"
                label: I18n.trFor("quickCapture", "Record Microphone")
                defaultValue: Defaults.values.recordMic
            }

            SelectionSettingPlus {
                visible: recordMic.value
                settingKey: "micDevice"
                label: I18n.trFor("quickCapture", "Microphone Device")
                options: root.daemon?.audioInputsList ?? root.fallbackInputs
                defaultValue: Defaults.values.micDevice
            }

            Separator {}

            ButtonGroupSettingPlus {
                settingKey: "audioCodec"
                label: I18n.trFor("quickCapture", "Audio Codec")
                options: [
                    {
                        label: "Opus",
                        value: "opus"
                    },
                    {
                        label: "AAC",
                        value: "aac"
                    },
                    {
                        label: "FLAC",
                        value: "flac"
                    }
                ]
                defaultValue: Defaults.values.audioCodec
            }

            Separator {}
        }

        ToggleSettingPlus {
            settingKey: "showPillBorder"
            label: I18n.trFor("quickCapture", "Show Pill Border")
            defaultValue: Defaults.values.showPillBorder
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "blinkRecordDot"
            label: I18n.trFor("quickCapture", "Blink Recording Dot")
            defaultValue: Defaults.values.blinkRecordDot
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "showRegionBorder"
            label: I18n.trFor("quickCapture", "Show Region Border")
            defaultValue: Defaults.values.showRegionBorder
        }
    }
}
