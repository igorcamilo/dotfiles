import QtQuick
import QtQml
import "./shared"

Item {
    id: root

    required property var context

    CurrentUser {
        id: currentUser
    }

    SystemUsers {
        id: systemUsers
    }

    property string fullName: {
        for (const u of systemUsers.users) {
            if (u.username === currentUser.username)
                return u.fullName;
        }
        return currentUser.username;
    }

    Image {
        anchors.fill: parent
        source: "file:///etc/wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#1a1b26aa"
    }

    Text {
        id: clockText
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.15
        color: "#c0caf5"
        font.pixelSize: 48
        // The system's LC_TIME chooses the 12/24-hour clock.
        text: new Date().toLocaleTimeString(Qt.locale(), Locale.ShortFormat)

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clockText.text = new Date().toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        }
    }

    AuthCard {
        anchors.centerIn: parent
        username: currentUser.username
        fullName: root.fullName
        busy: root.context.busy
        failureMessage: root.context.failureMessage
        onSubmitted: password => root.context.tryPassword(password)
    }
}
