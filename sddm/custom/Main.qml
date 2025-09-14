import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0
import QtMultimedia 5.15
import QtGraphicalEffects 1.15

Rectangle {
    id: container
    width: 1024
    height: 768
    color: "transparent"

    property string configFile: "theme.conf"
    property string backgroundSource: ""
    property string mediaType: ""
    property bool useRandomImages: false
    property string imageFolderPath: ""
    property int imageCount: 0
    property int currentImageIndex: 0

    // Charger la configuration depuis le fichier theme.conf
    function loadConfiguration() {
        // Cette fonction serait normalement implémentée avec un plugin C++
        // Pour cette démo, nous utilisons des valeurs par défaut
        backgroundSource = config.CustomBackgroundPath || ""
        mediaType = config.MediaType || ""
        useRandomImages = config.UseRandomImages || false
        imageFolderPath = config.ImageFolderPath || ""
        imageCount = config.ImageCount || 0
        
        // Déterminer le type de média basé sur l'extension du fichier
        if (mediaType === "" && backgroundSource !== "") {
            var extension = backgroundSource.split('.').pop().toLowerCase();
            if (extension === "mp4" || extension === "avi" || extension === "mov" || extension === "mkv") {
                mediaType = "video";
            } else if (extension === "gif") {
                mediaType = "gif";
            } else {
                mediaType = "image";
            }
        }
        
        // Mettre à jour les éléments d'affichage
        updateBackground();
    }

    function updateBackground() {
        if (useRandomImages && imageFolderPath !== "" && imageCount > 0) {
            // Mode images aléatoires
            randomImageTimer.start();
            showRandomImage();
        } else if (mediaType === "video") {
            // Mode vidéo
            videoBackground.source = backgroundSource;
            videoBackground.play();
            videoBackground.visible = true;
            animatedGifBackground.visible = false;
            staticImageBackground.visible = false;
        } else if (mediaType === "gif") {
            // Mode GIF animé
            animatedGifBackground.source = backgroundSource;
            animatedGifBackground.playing = true;
            videoBackground.visible = false;
            animatedGifBackground.visible = true;
            staticImageBackground.visible = false;
        } else {
            // Mode image statique
            staticImageBackground.source = backgroundSource;
            videoBackground.visible = false;
            animatedGifBackground.visible = false;
            staticImageBackground.visible = true;
        }
    }

    function showRandomImage() {
        if (imageCount > 0) {
            currentImageIndex = Math.floor(Math.random() * imageCount);
            staticImageBackground.source = "file://" + imageFolderPath + "/image" + currentImageIndex + ".jpg";
            videoBackground.visible = false;
            animatedGifBackground.visible = false;
            staticImageBackground.visible = true;
        }
    }

    Component.onCompleted: {
        loadConfiguration();
    }

    // Fond vidéo
    Video {
        id: videoBackground
        anchors.fill: parent
        loops: MediaPlayer.Infinite
        muted: true
        fillMode: VideoOutput.PreserveAspectCrop
        visible: false
    }

    // Fond GIF animé
    AnimatedImage {
        id: animatedGifBackground
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    // Fond image statique
    Image {
        id: staticImageBackground
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    // Timer pour changer les images aléatoires
    Timer {
        id: randomImageTimer
        interval: 10000 // 10 secondes
        repeat: true
        onTriggered: showRandomImage()
    }

    // Overlay semi-transparent pour améliorer la lisibilité
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4
    }

    // Interface utilisateur SDDM
    Rectangle {
        id: loginPanel
        width: 400
        height: 380
        anchors.centerIn: parent
        color: "#88112233"
        radius: 10
        border.color: "#55ffffff"
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 40

            // Logo ou titre
            Text {
                text: "Bienvenue"
                color: "white"
                font.pixelSize: 28
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Champ nom d'utilisateur
            Column {
                width: parent.width
                spacing: 5
                
                Text {
                    text: "Utilisateur:"
                    color: "white"
                    font.pixelSize: 14
                }
                
                TextField {
                    id: usernameField
                    width: parent.width
                    height: 40
                    placeholderText: "Nom d'utilisateur"
                    background: Rectangle {
                        color: "#22000000"
                        border.color: "#55ffffff"
                        border.width: 1
                        radius: 5
                    }
                    color: "white"
                    font.pixelSize: 16
                }
            }

            // Champ mot de passe
            Column {
                width: parent.width
                spacing: 5
                
                Text {
                    text: "Mot de passe:"
                    color: "white"
                    font.pixelSize: 14
                }
                
                TextField {
                    id: passwordField
                    width: parent.width
                    height: 40
                    placeholderText: "Mot de passe"
                    echoMode: TextInput.Password
                    background: Rectangle {
                        color: "#22000000"
                        border.color: "#55ffffff"
                        border.width: 1
                        radius: 5
                    }
                    color: "white"
                    font.pixelSize: 16
                }
            }

            // Sélecteur de session
            Column {
                width: parent.width
                spacing: 5
                
                Text {
                    text: "Session:"
                    color: "white"
                    font.pixelSize: 14
                }
                
                ComboBox {
                    id: sessionComboBox
                    width: parent.width
                    height: 40
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex
                    background: Rectangle {
                        color: "#22000000"
                        border.color: "#55ffffff"
                        border.width: 1
                        radius: 5
                    }
                    popup.contentItem: ListView {
                        model: sessionComboBox.model
                        currentIndex: sessionComboBox.highlightedIndex
                        delegate: ItemDelegate {
                            width: parent.width
                            text: model[name]
                            highlighted: sessionComboBox.highlightedIndex === index
                            background: Rectangle { color: highlighted ? "#44336699" : "#22112233" }
                        }
                    }
                }
            }

            // Boutons d'action
            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter
                
                Button {
                    text: "Connexion"
                    width: 120
                    height: 40
                    onClicked: sddm.login(usernameField.text, passwordField.text, sessionComboBox.currentIndex)
                    background: Rectangle {
                        color: parent.down ? "#3366aa66" : (parent.hovered ? "#44aaeeaa" : "#3366aa99")
                        radius: 5
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Button {
                    text: "Arrêt"
                    width: 80
                    height: 40
                    onClicked: sddm.powerOff()
                    background: Rectangle {
                        color: parent.down ? "#33aa6666" : (parent.hovered ? "#44eeaaaa" : "#33aa6666")
                        radius: 5
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Button {
                    text: "Redémarrage"
                    width: 120
                    height: 40
                    onClicked: sddm.reboot()
                    background: Rectangle {
                        color: parent.down ? "#3366aaaa" : (parent.hovered ? "#44aaaaff" : "#3366aaaa")
                        radius: 5
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // Horloge
    Text {
        id: timeText
        anchors {
            top: parent.top
            right: parent.right
            margins: 20
        }
        color: "white"
        font.pixelSize: 48
        font.bold: true
        
        function updateTime() {
            var date = new Date();
            timeText.text = date.toLocaleTimeString(Qt.locale(), "hh:mm");
        }
        
        Component.onCompleted: {
            updateTime();
            timeUpdateTimer.start();
        }
    }
    
    Timer {
        id: timeUpdateTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: timeText.updateTime()
    }
    
    // Date
    Text {
        id: dateText
        anchors {
            top: timeText.bottom
            right: parent.right
            margins: 20
        }
        color: "white"
        font.pixelSize: 18
        
        function updateDate() {
            var date = new Date();
            dateText.text = date.toLocaleDateString(Qt.locale(), "dddd, MMMM d");
        }
        
        Component.onCompleted: {
            updateDate();
            dateUpdateTimer.start();
        }
    }
    
    Timer {
        id: dateUpdateTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: dateText.updateDate()
    }

    // Message d'erreur
    Text {
        id: errorMessage
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            margins: 20
        }
        color: "#ff6666"
        font.pixelSize: 14
        visible: text !== ""
    }

    // Connexions aux signaux SDDM
    Connections {
        target: sddm
        
        function onLoginSucceeded() {
            errorMessage.color = "#66ff66";
            errorMessage.text = "Connexion réussie";
        }
        
        function onLoginFailed() {
            errorMessage.color = "#ff6666";
            errorMessage.text = "Échec de la connexion";
            passwordField.text = "";
        }
    }

    // Focus initial
    Component.onCompleted: {
        usernameField.focus = true;
        if (usernameField.text === "") {
            usernameField.focus = true;
        } else {
            passwordField.focus = true;
        }
    }
}
