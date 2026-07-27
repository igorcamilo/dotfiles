import QtQuick

// Picture from /var/lib/AccountsService/icons/<username> (the same
// convention GDM/lightdm/regreet use) if one exists, else a plain
// initial-letter circle. No avatar files are required or committed.
Item {
    id: root

    property string username: ""
    property string fullName: ""
    property int size: 96

    width: size
    height: size

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color: "#565f89"
        clip: true

        Image {
            id: avatarImage
            anchors.fill: parent
            source: root.username.length > 0 ? "file:///var/lib/AccountsService/icons/" + root.username : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: avatarImage.status !== Image.Ready
            color: "#c0caf5"
            font.pixelSize: root.size * 0.4
            text: {
                const label = root.fullName.length > 0 ? root.fullName : root.username;
                return label.length > 0 ? label.charAt(0).toUpperCase() : "?";
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: "#c0caf5"
        border.width: 2
    }
}
