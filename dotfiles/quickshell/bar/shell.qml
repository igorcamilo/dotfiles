import QtQuick
import QtQml
import Quickshell
import Quickshell.Wayland

ShellRoot {
    // Wallpaper: one background layer-shell surface per screen.
    // configuration.nix installs the repository image at /etc/wallpaper.jpg.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "black"

            Image {
                anchors.fill: parent
                source: "file:///etc/wallpaper.jpg"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
    }

    // Bar: current date/time, top of each screen.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 32
            color: "#1a1b26"

            Text {
                id: clockText
                anchors.centerIn: parent
                color: "#c0caf5"
                font.pixelSize: 14
                // The system's LC_TIME chooses date order and 12/24-hour time.
                text: new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)
                }
            }
        }
    }
}
