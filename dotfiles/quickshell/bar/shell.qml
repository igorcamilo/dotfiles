import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    // Wallpaper: one background layer-shell surface per screen.
    // Swap the path below for a real image; none is committed here.
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
                source: "file:///home/igor/Pictures/wallpaper.jpg"
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
                text: Qt.formatDateTime(new Date(), "yyyy-MM-dd  HH:mm:ss")

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd  HH:mm:ss")
                }
            }
        }
    }
}
