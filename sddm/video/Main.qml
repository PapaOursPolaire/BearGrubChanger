/* 
Auteur : PapaOursPolaire
Repo GitHub : https://github.com/PapaOursPolaire/BearGrubChanger
Contact : papaourspolairegithub@gmail.com
*/
import QtMultimedia 5.13
import QtQuick 2.15
import SddmComponents 2.0
import QtQuick.Controls 2.15
import Qt.labs.folderlistmodel 2.15

Rectangle {
    id: container
    width: 640
    height: 480

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.index
    property string customBackgroundPath: config.CustomBackgroundPath || ""
    property bool useRandomImages: config.UseRandomImages || false
    property string imageFolderPath: config.ImageFolderPath || "/usr/share/sddm/themes/custom/backgrounds"

    TextConstants { id: textConstants }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            errorMessage.color = "steelblue"
            errorMessage.text = textConstants.loginSucceeded
        }

        function onLoginFailed() {
            password.text = ""
            errorMessage.color = "red"
            errorMessage.text = textConstants.loginFailed
        }

        function onInformationMessage(message) {
            errorMessage.color = "red"
            errorMessage.text = message
        }
    }

    // ---------- FOND D'ÉCRAN DYNAMIQUE ----------
    Item {
        id: background
        anchors.fill: parent

        // Mode images aléatoires
        Image {
            id: randomImage
            anchors.fill: parent
            source: useRandomImages && imageFolderModel.count > 0 ? 
                   "file://" + imageFolderModel.get(currentImageIndex, "filePath") : ""
            fillMode: Image.PreserveAspectCrop
            visible: useRandomImages && imageFolderModel.count > 0
            smooth: true
            
            Timer {
                interval: 5000 // Change d'image toutes les 5 secondes
                running: useRandomImages && imageFolderModel.count > 1
                repeat: true
                onTriggered: {
                    currentImageIndex = (currentImageIndex + 1) % imageFolderModel.count
                }
            }
        }

        // Mode vidéo/GIF personnalisé
        AnimatedImage {
            id: customGif
            anchors.fill: parent
            source: !useRandomImages && customBackgroundPath.endsWith(".gif") ? 
                   "file://" + customBackgroundPath : ""
            fillMode: Image.PreserveAspectCrop
            playing: true
            visible: !useRandomImages && customBackgroundPath.endsWith(".gif")
            smooth: true
        }

        Video {
            id: customVideo
            anchors.fill: parent
            source: !useRandomImages && (customBackgroundPath.endsWith(".mp4") || 
                    customBackgroundPath.endsWith(".webm") || 
                    customBackgroundPath.endsWith(".avi")) ? 
                   "file://" + customBackgroundPath : ""
            autoPlay: true
            loops: MediaPlayer.Infinite
            muted: true
            fillMode: VideoOutput.PreserveAspectCrop
            visible: !useRandomImages && (customBackgroundPath.endsWith(".mp4") || 
                     customBackgroundPath.endsWith(".webm") || 
                     customBackgroundPath.endsWith(".avi"))

            onStatusChanged: {
                if (status === MediaPlayer.InvalidMedia) {
                    fallbackBackground.visible = true
                }
            }
        }

        // Fallback si aucun média valide
        Rectangle {
            id: fallbackBackground
            anchors.fill: parent
            color: "black"
            visible: (useRandomImages && imageFolderModel.count === 0) || 
                    (!useRandomImages && customBackgroundPath === "")
        }
    }

    // Modèle pour charger les images du dossier
    FolderListModel {
        id: imageFolderModel
        folder: "file://" + imageFolderPath
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp"]
        showDirs: false
        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                console.log("Images trouvées:", count)
            }
        }
    }

    property int currentImageIndex: 0

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Clock {
            id: clock
            anchors.margins: 40
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: 40
            color: "#eaf5c4"

            timeFont {
                family: "Consolas"
                bold: true
                pixelSize: 90
            }

            dateFont {
                family: "Lucida Console"
                bold: true
                pixelSize: 30
            }
        }

        Image {
            id: rectangle
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: Math.max(370, mainColumn.implicitWidth + 50)
            height: Math.max(320, mainColumn.implicitHeight + 50)
            source: "loginterminalc.png"

            Column {
                id: mainColumn
                anchors.centerIn: parent
                spacing: 12

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "black"
                    verticalAlignment: Text.AlignVCenter
                    height: text.implicitHeight
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 24
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Column {
                    width: parent.width
                    spacing: 4
                    Text {
                        id: lblName
                        width: parent.width
                        text: textConstants.userName
                        color: "#88FF88"
                        font.bold: true
                        font.pixelSize: 12
                    }

                    TextBox {
                        id: name
                        width: parent.width; height: 30
                        text: userModel.lastUser
                        textColor: "#88FF88"
                        color: "transparent"
                        font.pixelSize: 14

                        KeyNavigation.backtab: rebootButton; KeyNavigation.tab: password

                        Keys.onPressed: {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                sddm.login(name.text, password.text, sessionIndex)
                                event.accepted = true
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4
                    Text {
                        id: lblPassword
                        width: parent.width
                        text: textConstants.password
                        color: "#88FF88"
                        font.bold: true
                        font.pixelSize: 12
                    }

                    PasswordBox {
                        id: password
                        width: parent.width; height: 30
                        font.pixelSize: 14
                        textColor: "#88FF88"
                        color: "transparent"

                        KeyNavigation.backtab: name; KeyNavigation.tab: session

                        Keys.onPressed: {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                sddm.login(name.text, password.text, sessionIndex)
                                event.accepted = true
                            }
                        }
                    }
                }

                Row {
                    spacing: 4
                    width: parent.width / 2

                    Column {
                        width: parent.width * 1.3
                        spacing: 4
                        anchors.bottom: parent.bottom

                        Text {
                            id: lblSession
                            width: parent.width
                            text: textConstants.session
                            color: "#88FF88"
                            wrapMode: TextEdit.WordWrap
                            font.bold: true
                            font.pixelSize: 12
                        }

                        ComboBox {
                            id: session
                            width: parent.width; height: 30
                            font.pixelSize: 14
                            color: "transparent"
                            arrowIcon: "angle-down.png"
                            model: sessionModel
                            index: sessionModel.lastIndex

                            KeyNavigation.backtab: password; KeyNavigation.tab: layoutBox
                        }
                    }

                    Column {
                        width: parent.width * 0.7
                        spacing: 4
                        anchors.bottom: parent.bottom

                        Text {
                            id: lblLayout
                            width: parent.width
                            text: textConstants.layout
                            wrapMode: TextEdit.WordWrap
                            font.bold: true
                            font.pixelSize: 12
                            color: "#88FF88"
                        }

                        LayoutBox {
                            id: layoutBox
                            width: parent.width; height: 30
                            font.pixelSize: 14
                            color: "transparent"
                            arrowIcon: "angle-down.png"

                            KeyNavigation.backtab: session; KeyNavigation.tab: loginButton
                        }
                    }
                }

                Column {
                    width: parent.width
                    Text {
                        id: errorMessage
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: textConstants.prompt
                        font.pixelSize: 10
                        color: "#88FF88"
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter

                    Button {
                        id: loginButton
                        text: textConstants.login
                        width: 73
                        height: 75
                        color: "transparent"
                        textColor: "green"
                        enabled: true

                        onClicked: sddm.login(name.text, password.text, sessionIndex)

                        KeyNavigation.backtab: layoutBox; KeyNavigation.tab: shutdownButton

                        anchors.top: parent.bottom
                        anchors.topMargin: -24

                        MouseArea {
                            width: parent.width
                            height: parent.height
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = "transparent"
                            onExited: parent.color = "transparent"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sddm.login(name.text, password.text, sessionIndex)
                        }
                    }

                    Button {
                        id: rebootButton
                        text: textConstants.reboot
                        width: 73
                        height: 75
                        color: "transparent"
                        textColor: "yellow"
                        enabled: true

                        onClicked: sddm.reboot()

                        KeyNavigation.backtab: shutdownButton; KeyNavigation.tab: name

                        anchors.top: parent.bottom
                        anchors.topMargin: -24

                        MouseArea {
                            width: parent.width
                            height: parent.height
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = "transparent"
                            onExited: parent.color = "transparent"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sddm.reboot()
                        }
                    }

                    Button {
                        id: shutdownButton
                        text: "Power"
                        width: 73
                        height: 75
                        color: "transparent"
                        textColor: "red"
                        enabled: true

                        onClicked: sddm.powerOff()

                        KeyNavigation.backtab: loginButton; KeyNavigation.tab: rebootButton

                        anchors.top: parent.bottom
                        anchors.topMargin: -24

                        MouseArea {
                            width: parent.width
                            height: parent.height
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = "transparent"
                            onExited: parent.color = "transparent"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sddm.powerOff()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (name.text === "")
            name.focus = false
        else
            password.focus = true
    }
}
