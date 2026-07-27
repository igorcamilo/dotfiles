import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    PanelWindow {
        id: launcher

        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"

        property string query: ""

        function launchSelected() {
            if (list.currentItem && list.currentItem.modelData) {
                list.currentItem.modelData.execute();
                Qt.quit();
            }
        }

        // Click outside the card to dismiss.
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }

        Rectangle {
            anchors.centerIn: parent
            width: 560
            height: 360
            radius: 8
            color: "#1a1b26"

            MouseArea {
                // Swallow clicks so they don't reach the dismiss MouseArea behind.
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                TextField {
                    id: input
                    Layout.fillWidth: true
                    placeholderText: "Run..."
                    font.pixelSize: 18
                    color: "#c0caf5"
                    focus: true
                    padding: 12

                    background: Rectangle {
                        color: "transparent"
                    }

                    onTextChanged: {
                        launcher.query = text;
                        list.currentIndex = filtered.values.length > 0 ? 0 : -1;
                    }

                    Keys.onEscapePressed: Qt.quit()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Up) {
                            event.accepted = true;
                            if (list.currentIndex > 0)
                                list.currentIndex--;
                        } else if (event.key === Qt.Key_Down) {
                            event.accepted = true;
                            if (list.currentIndex < list.count - 1)
                                list.currentIndex++;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            event.accepted = true;
                            launcher.launchSelected();
                        }
                    }
                }

                ScriptModel {
                    id: filtered
                    values: {
                        const all = [...DesktopEntries.applications.values];
                        const q = launcher.query.trim().toLowerCase();
                        return q === "" ? all : all.filter(d => d.name && d.name.toLowerCase().includes(q));
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: filtered.values
                    currentIndex: filtered.values.length > 0 ? 0 : -1
                    highlight: Rectangle {
                        radius: 4
                        color: "#c0caf5"
                        opacity: 0.2
                    }

                    delegate: Item {
                        id: entry
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 36

                        MouseArea {
                            anchors.fill: parent
                            onClicked: list.currentIndex = entry.index
                            onDoubleClicked: launcher.launchSelected()
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            IconImage {
                                source: Quickshell.iconPath(modelData.icon, true)
                                width: 20
                                height: 20
                            }

                            Text {
                                text: modelData.name
                                color: "#c0caf5"
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
