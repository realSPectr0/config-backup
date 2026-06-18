import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: wpWindow

    property color bg: "#0e1120"
    property color primary: "#a3c9ff"
    property color fg: "#e1e2e9"
    property color dim: "#5d6172"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    property color yellow: "#f9e2af"
    property color purple: "#cba6f7"
    property string fontFamily: "JetBrainsMono Nerd Font"

    property bool showing: false
    property var localWallpapers: []
    property var collectionWallpapers: []
    property var onlineWallpapers: []
    property string searchText: ""
    property string onlineQuery: ""
    property int onlinePage: 1
    property int onlinePerPage: 24
    property bool onlineCanLoadMore: true
    property bool onlineAppending: false
    property string currentTab: "local" // "local", "collection", or "online"

    // Keyboard Navigation State
    property int selectedIndex: 0
    property var filteredWallpapers: {
        var base = wpWindow.currentTab === "local" ? wpWindow.localWallpapers : 
                   wpWindow.currentTab === "collection" ? wpWindow.collectionWallpapers :
                   wpWindow.onlineWallpapers;
        if (wpWindow.searchText === "") return base;
        return base.filter(w => w.name.toLowerCase().includes(wpWindow.searchText.toLowerCase()));
    }

    onFilteredWallpapersChanged: if (!wpWindow.onlineAppending) selectedIndex = 0

    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    color: Qt.rgba(0, 0, 0, 0.5) // Scrim

    function moveSelection(row, col) {
        var cols = 4;
        var newIndex = selectedIndex + (row * cols) + col;
        if (newIndex >= 0 && newIndex < filteredWallpapers.length) {
            selectedIndex = newIndex;
            ensureVisible();
        }
    }

    function ensureVisible() {
        var row = Math.floor(selectedIndex / 4);
        var itemHeight = grid.cellHeight + grid.spacing;
        var viewTop = scroll.contentY;
        var viewBottom = viewTop + scroll.height;
        var itemTop = row * itemHeight;
        var itemBottom = itemTop + grid.cellHeight;

        if (itemTop < viewTop) scroll.contentY = itemTop;
        else if (itemBottom > viewBottom) scroll.contentY = itemBottom - scroll.height;
    }

    function applySelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredWallpapers.length) {
            var wall = filteredWallpapers[selectedIndex];
            applyProc.command = ["/home/arch/.config/hypr/scripts/apply-wallpaper.sh", wall.source, wall.full, wall.name];
            applyProc.running = true;
            wpWindow.showing = false;
        }
    }

    Process {
        id: localProc
        command: ["/home/arch/.config/hypr/scripts/wallpaper-list.py", "--local-only"]
        stdout: SplitParser { onRead: data => {
            try { wpWindow.localWallpapers = JSON.parse(data); } catch(e) {}
        }}
    }

    Process {
        id: collectionProc
        command: ["/home/arch/.config/hypr/scripts/wallpaper-list.py", "--collection-only"]
        stdout: SplitParser { onRead: data => {
            try { wpWindow.collectionWallpapers = JSON.parse(data); } catch(e) {}
        }}
    }

    Process {
        id: onlineProc
        command: ["python3", "/home/arch/.config/hypr/scripts/wallpaper-list.py", "--online-only", "--query", wpWindow.onlineQuery, "--page", wpWindow.onlinePage]
        stdout: SplitParser { onRead: data => {
            try { 
                var parsed = JSON.parse(data);
                if (Array.isArray(parsed)) {
                    if (wpWindow.onlineAppending) {
                        wpWindow.onlineWallpapers = wpWindow.onlineWallpapers.concat(parsed);
                    } else {
                        wpWindow.onlineWallpapers = parsed;
                    }
                    if (parsed.length < wpWindow.onlinePerPage) wpWindow.onlineCanLoadMore = false;
                    wpWindow.onlineAppending = false;
                }
            } catch(e) {}
        }}
    }

    onShowingChanged: if (showing) { 
        wpWindow.searchText = "";
        wpWindow.onlineQuery = "";
        searchInput.text = "";
        localProc.running = true; 
        collectionProc.running = true;
        searchInput.forceActiveFocus(); 
    }
    
    onCurrentTabChanged: {
        wpWindow.searchText = "";
        searchInput.text = "";
        if (showing && currentTab === "collection") collectionProc.running = true;
    }

    // Click outside to dismiss (don't eat scroll)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onWheel: (wheel) => { wheel.accepted = false; }
        onClicked: wpWindow.showing = false
    }

    Rectangle {
        id: mainCard
        anchors.centerIn: parent
        width: 1100; height: 650; radius: 24
        color: wpWindow.bg
        border.width: 2; border.color: Qt.rgba(wpWindow.primary.r, wpWindow.primary.g, wpWindow.primary.b, 0.3)
        clip: true

        opacity: wpWindow.showing ? 1.0 : 0.0
        scale: wpWindow.showing ? 1.0 : 0.9
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            // Header / Tabs
            Rectangle {
                Layout.fillWidth: true
                height: 70
                color: Qt.rgba(1, 1, 1, 0.02)
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 30; anchors.rightMargin: 30
                    spacing: 30

                    Text {
                        text: "󰸉 Wallpapers"
                        color: wpWindow.fg
                        font { pixelSize: 20; family: wpWindow.fontFamily; bold: true }
                    }

                    // Tabs
                    Row {
                        spacing: 10
                        Layout.alignment: Qt.AlignVCenter
                        
                        Repeater {
                            model: [
                                { id: "local", label: "󰋜 Local", color: wpWindow.green },
                                { id: "collection", label: "󰄭 Saved", color: wpWindow.purple },
                                { id: "online", label: "󰖟 Online", color: wpWindow.yellow }
                            ]
                            
                            Rectangle {
                                required property var modelData
                                width: 110; height: 36; radius: 18
                                color: wpWindow.currentTab === modelData.id ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.2) : "transparent"
                                border.width: 1; border.color: wpWindow.currentTab === modelData.id ? modelData.color : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: wpWindow.currentTab === modelData.id ? modelData.color : wpWindow.dim
                                    font { pixelSize: 13; family: wpWindow.fontFamily; bold: wpWindow.currentTab === modelData.id }
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: wpWindow.currentTab = parent.modelData.id
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Search Box
                    Rectangle {
                        width: 250; height: 36; radius: 18
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1; border.color: searchInput.activeFocus ? wpWindow.primary : Qt.rgba(1, 1, 1, 0.1)

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            anchors.leftMargin: 15; anchors.rightMargin: 15
                            verticalAlignment: TextInput.AlignVCenter
                            color: wpWindow.fg
                            font { pixelSize: 13; family: wpWindow.fontFamily }
                            onTextChanged: wpWindow.searchText = text
                            
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Down) { moveSelection(1, 0); event.accepted = true; }
                                else if (event.key === Qt.Key_Up) { moveSelection(-1, 0); event.accepted = true; }
                                else if (event.key === Qt.Key_Left) { moveSelection(0, -1); event.accepted = true; }
                                else if (event.key === Qt.Key_Right) { moveSelection(0, 1); event.accepted = true; }
                                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (wpWindow.currentTab === "online" && wpWindow.searchText !== "") {
                                        wpWindow.onlineQuery = wpWindow.searchText;
                                        wpWindow.onlinePage = 1;
                                        wpWindow.onlineCanLoadMore = true;
                                        wpWindow.onlineAppending = false;
                                        wpWindow.onlineWallpapers = [];
                                        onlineProc.running = false;
                                        onlineProc.running = true;
                                        wpWindow.searchText = "";
                                        searchInput.text = "";
                                    } else {
                                        applySelected();
                                    }
                                    event.accepted = true;
                                }
                            }
                            
                            Text {
                                text: wpWindow.currentTab === "online" ? "Search online..." : "Filter list..."
                                color: wpWindow.dim
                                visible: parent.text === ""
                                font: parent.font
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                            }
                        }
                    }

                    // Search/Refresh button
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: refreshMA.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                        visible: wpWindow.currentTab === "online"
                        
                        Text { 
                            anchors.centerIn: parent; 
                            text: onlineProc.running ? "󰑐" : "󰄭"; 
                            color: wpWindow.fg; 
                            font.pixelSize: 16 
                            RotationAnimation on rotation {
                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite; 
                                running: onlineProc.running
                            }
                        }
                        
                        MouseArea { id: refreshMA; anchors.fill: parent; hoverEnabled: true; 
                            onClicked: {
                                var q = wpWindow.searchText !== "" ? wpWindow.searchText : wpWindow.onlineQuery;
                                wpWindow.onlineQuery = q;
                                wpWindow.onlinePage = 1;
                                wpWindow.onlineCanLoadMore = true;
                                wpWindow.onlineAppending = false;
                                wpWindow.onlineWallpapers = [];
                                onlineProc.running = false;
                                onlineProc.running = true;
                                wpWindow.searchText = "";
                                searchInput.text = "";
                            }
                        }
                    }
                }
                
                Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; height: 1
                    color: Qt.rgba(1, 1, 1, 0.05)
                }
            }

            // Grid Content
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                Flickable {
                    id: scroll
                    anchors.fill: parent
                    anchors.margins: 20
                    clip: true
                    contentWidth: grid.width
                    contentHeight: grid.contentHeight
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    onContentYChanged: {
                        if (wpWindow.currentTab !== "online") return;
                        if (!wpWindow.onlineCanLoadMore || onlineProc.running) return;
                        if (scroll.contentY + scroll.height >= scroll.contentHeight - 200) {
                            wpWindow.onlinePage += 1;
                            wpWindow.onlineAppending = true;
                            onlineProc.running = false;
                            onlineProc.running = true;
                        }
                    }

                    Grid {
                        id: grid
                        columns: 4
                        spacing: 20
                        width: parent.width - 20
                        property real cellWidth: Math.max(0, (grid.width - (grid.spacing * (grid.columns - 1))) / grid.columns)
                        property real cellHeight: grid.cellWidth * 0.65
                        property int rowCount: wpWindow.filteredWallpapers.length === 0 ? 0 : Math.ceil(wpWindow.filteredWallpapers.length / grid.columns)
                        property real contentHeight: rowCount === 0 ? 0 : (rowCount * grid.cellHeight) + ((rowCount - 1) * grid.spacing)

                        Repeater {
                            model: wpWindow.filteredWallpapers

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: grid.cellWidth
                                height: grid.cellHeight; radius: 16
                                color: Qt.rgba(1, 1, 1, 0.03)
                                border.width: 3
                                border.color: wpWindow.selectedIndex === index 
                                    ? wpWindow.primary 
                                    : (itemMA.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05))
                                clip: true
                                
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                // Pulsing selection effect
                                SequentialAnimation on border.color {
                                    running: wpWindow.selectedIndex === index
                                    loops: Animation.Infinite
                                    ColorAnimation { to: Qt.lighter(wpWindow.primary, 1.2); duration: 800 }
                                    ColorAnimation { to: wpWindow.primary; duration: 800 }
                                }

                                Image {
                                    anchors.fill: parent
                                    source: modelData.thumb
                                    sourceSize.width: 320
                                    sourceSize.height: 200
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    
                                    // Loading indicator
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(0, 0, 0, 0.3)
                                        visible: parent.status !== Image.Ready
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰄦"
                                            color: wpWindow.dim
                                            font.pixelSize: 32
                                        }
                                    }
                                }

                                // Name overlay on hover or selection
                                Rectangle {
                                    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                                    height: 40
                                    color: Qt.rgba(0, 0, 0, 0.7)
                                    visible: itemMA.containsMouse || wpWindow.selectedIndex === index
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        width: parent.width - 20
                                        text: modelData.name
                                        color: wpWindow.fg
                                        font { pixelSize: 11; family: wpWindow.fontFamily; bold: wpWindow.selectedIndex === index }
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: itemMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    scrollGestureEnabled: false
                                    onWheel: (wheel) => { wheel.accepted = false; }
                                    onClicked: {
                                        wpWindow.selectedIndex = index;
                                        applySelected();
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Empty state / Loading
                Column {
                    anchors.centerIn: parent
                    spacing: 15
                    visible: (wpWindow.currentTab === "online" && (onlineProc.running || onlineWallpapers.length === 0)) || 
                             (wpWindow.currentTab === "local" && localWallpapers.length === 0) ||
                             (wpWindow.currentTab === "collection" && collectionWallpapers.length === 0 && !collectionProc.running)
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (onlineProc.running || collectionProc.running) ? "󰑐" : "󰸉"
                        color: wpWindow.dim
                        font.pixelSize: 48
                        RotationAnimation on rotation {
                            from: 0; to: 360; duration: 1000; loops: Animation.Infinite; 
                            running: (onlineProc.running || collectionProc.running)
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: onlineProc.running ? "Searching Wallhaven..." : 
                              (wpWindow.currentTab === "online" && onlineWallpapers.length === 0) ? "Type a query and press Enter to search" :
                              collectionProc.running ? "Loading saved collection..." : "No wallpapers found"
                        color: wpWindow.dim
                        font { pixelSize: 16; family: wpWindow.fontFamily }
                    }
                }
            }
        }
    }

    Process { id: applyProc }

    // Global Shortcuts
    Shortcut { sequence: "Escape"; onActivated: wpWindow.showing = false }
    Shortcut { sequence: "Tab"; onActivated: {
        if (wpWindow.currentTab === "local") wpWindow.currentTab = "collection";
        else if (wpWindow.currentTab === "collection") wpWindow.currentTab = "online";
        else wpWindow.currentTab = "local";
    } }
    
    // HJKL / Vim Binds
    Shortcut { sequence: "h"; onActivated: moveSelection(0, -1) }
    Shortcut { sequence: "j"; onActivated: moveSelection(1, 0) }
    Shortcut { sequence: "k"; onActivated: moveSelection(-1, 0) }
    Shortcut { sequence: "l"; onActivated: moveSelection(0, 1) }
    
    // Also support Space for applying (since Enter might be used in search)
    Shortcut { sequence: "Space"; onActivated: applySelected() }
}
