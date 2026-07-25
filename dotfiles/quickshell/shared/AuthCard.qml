import QtQuick

// Shared by the greeter and the lock screen: same look, different
// data and a different submit handler wired up by the caller.
Column {
    id: root

    property string username: ""
    property string fullName: ""
    property bool busy: false
    property string failureMessage: ""

    signal submitted(string password)

    spacing: 16
    width: 240

    UserAvatar {
        anchors.horizontalCenter: parent.horizontalCenter
        username: root.username
        fullName: root.fullName
        size: 96
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#c0caf5"
        font.pixelSize: 18
        text: root.fullName.length > 0 ? root.fullName : root.username
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#565f89"
        font.pixelSize: 13
        text: root.username
        visible: root.fullName.length > 0 && root.fullName !== root.username
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
            enabled: !root.busy

            Keys.onReturnPressed: {
                root.submitted(text);
                text = "";
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#f7768e"
        text: root.failureMessage
        visible: text.length > 0
    }
}
