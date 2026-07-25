import QtQuick

Item {
    id: root

    required property var context

    Rectangle {
        anchors.fill: parent
        color: "#1a1b26"
    }

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: 240

        Text {
            id: clockText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#c0caf5"
            font.pixelSize: 28
            text: Qt.formatDateTime(new Date(), "HH:mm")

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
            }
        }

        Rectangle {
            width: parent.width
            height: 32
            color: "transparent"
            border.color: "#565f89"

            TextInput {
                id: passField
                anchors.fill: parent
                anchors.margins: 6
                color: "#c0caf5"
                font.pixelSize: 16
                echoMode: TextInput.Password
                focus: true
                enabled: !root.context.busy

                Keys.onReturnPressed: {
                    root.context.tryPassword(text);
                    text = "";
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#f7768e"
            text: root.context.failureMessage
            visible: text.length > 0
        }
    }
}
