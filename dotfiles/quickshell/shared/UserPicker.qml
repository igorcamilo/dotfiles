import QtQuick

// macOS-style row of accounts; clicking one is reported via
// userSelected so the caller can swap in an AuthCard for them.
Row {
    id: root

    property var users: []

    signal userSelected(string username, string fullName)

    spacing: 32

    Repeater {
        model: root.users

        Column {
            id: entry
            required property var modelData

            spacing: 8

            UserAvatar {
                id: avatar
                anchors.horizontalCenter: parent.horizontalCenter
                username: entry.modelData.username
                fullName: entry.modelData.fullName
                size: 72

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.userSelected(entry.modelData.username, entry.modelData.fullName)
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#c0caf5"
                font.pixelSize: 14
                text: entry.modelData.fullName.length > 0 ? entry.modelData.fullName : entry.modelData.username
            }
        }
    }
}
