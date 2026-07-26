import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

PanelWindow {
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        right: true
    }
    margins {
        top: 40
        right: 10
    }
    implicitWidth: 340
    implicitHeight: column.implicitHeight
    color: "transparent"

    NotificationServer {
        id: server
        bodySupported: true

        onNotification: notif => {
            notif.tracked = true;
        }
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            model: server.trackedNotifications

            delegate: Rectangle {
                id: card
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: content.implicitHeight + 24
                radius: 8
                color: "#1a1b26"

                RowLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    IconImage {
                        source: Quickshell.iconPath(card.modelData.appIcon, true)
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignTop
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.appName
                            color: "#c0caf5"
                            opacity: 0.6
                            font.pixelSize: 11
                        }
                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.summary
                            color: "#c0caf5"
                            font.pixelSize: 14
                            font.bold: true
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: card.modelData.body !== ""
                            text: card.modelData.body
                            color: "#c0caf5"
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: card.modelData.dismiss()
                }

                Timer {
                    running: true
                    interval: card.modelData.expireTimeout > 0 ? card.modelData.expireTimeout * 1000 : 5000
                    onTriggered: card.modelData.expire()
                }
            }
        }
    }
}
