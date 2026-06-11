import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: rootWidget

    pluginId: "desktopWidgetToggle"
    pluginService: PluginService

    // Local reactive views of the settings
    property var groups: pluginData.groups ?? [
        { "id": "g1", "name": "Group 1", "icon": "widgets", "widgets": [], "autoDismissDuration": 0 }
    ]
    property string conflictMode: pluginData.conflictMode ?? "single"
    property var activeGroupIds: pluginData.activeGroupIds ?? []

    horizontalBarPill: Component {
        Item {
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height

            Row {
                id: horizontalRow
                spacing: Theme.spacingS
                height: rootWidget.widgetThickness

                Repeater {
                    model: rootWidget.groups

                    delegate: StyledRect {
                        id: btn
                        required property var modelData

                        width: contentRow.width + Theme.spacingM * 2
                        height: parent.height
                        radius: Theme.cornerRadius

                        readonly property bool isActive: rootWidget.activeGroupIds.includes(modelData.id)
                        readonly property bool isDisabled: {
                            if (isActive) return false;
                            if (rootWidget.conflictMode === "single") {
                                return rootWidget.activeGroupIds.length > 0;
                            }
                            if (rootWidget.conflictMode === "overlap") {
                                const daemon = pluginService.pluginInstances[rootWidget.pluginId];
                                return daemon ? daemon.hasOverlapWithActive(modelData.id, rootWidget.activeGroupIds) : false;
                            }
                            return false;
                        }

                        color: isActive ? Theme.primary : (isDisabled ? Theme.surfaceContainerLow : Theme.surfaceContainerHigh)
                        opacity: isDisabled ? 0.4 : 1.0

                        Row {
                            id: contentRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: modelData.icon || "widgets"
                                size: Theme.barIconSize(rootWidget.barThickness, -4, rootWidget.barConfig?.maximizeWidgetIcons, rootWidget.barConfig?.iconScale)
                                color: btn.isActive ? Theme.onPrimary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { enabled: false }
                                visible: modelData.showIcon !== false && name !== ""
                            }

                            StyledText {
                                text: modelData.name || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: btn.isActive ? Theme.onPrimary : Theme.surfaceText
                                visible: modelData.name !== ""
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !btn.isDisabled
                            cursorShape: btn.isDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                const daemon = pluginService.pluginInstances[rootWidget.pluginId];
                                if (daemon) {
                                    daemon.toggleGroup(modelData.id);
                                } else {
                                    console.warn("[desktopWidgetToggle] Daemon not found; fallback to settings change");
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height

            Column {
                id: verticalColumn
                spacing: Theme.spacingS
                width: rootWidget.widgetThickness

                Repeater {
                    model: rootWidget.groups

                    delegate: StyledRect {
                        id: btn
                        required property var modelData

                        width: parent.width
                        height: width
                        radius: Theme.cornerRadius

                        readonly property bool isActive: rootWidget.activeGroupIds.includes(modelData.id)
                        readonly property bool isDisabled: {
                            if (isActive) return false;
                            if (rootWidget.conflictMode === "single") {
                                return rootWidget.activeGroupIds.length > 0;
                            }
                            if (rootWidget.conflictMode === "overlap") {
                                const daemon = pluginService.pluginInstances[rootWidget.pluginId];
                                return daemon ? daemon.hasOverlapWithActive(modelData.id, rootWidget.activeGroupIds) : false;
                            }
                            return false;
                        }

                        color: isActive ? Theme.primary : (isDisabled ? Theme.surfaceContainerLow : Theme.surfaceContainerHigh)
                        opacity: isDisabled ? 0.4 : 1.0

                        DankIcon {
                            name: modelData.icon || "widgets"
                            size: Theme.barIconSize(rootWidget.barThickness, -4, rootWidget.barConfig?.maximizeWidgetIcons, rootWidget.barConfig?.iconScale)
                            color: btn.isActive ? Theme.onPrimary : Theme.surfaceText
                            anchors.centerIn: parent
                            Behavior on color { enabled: false }
                            visible: modelData.showIcon !== false
                        }

                        StyledText {
                            text: (modelData.name || "").substring(0, 2)
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: btn.isActive ? Theme.onPrimary : Theme.surfaceText
                            anchors.centerIn: parent
                            visible: modelData.showIcon === false
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !btn.isDisabled
                            cursorShape: btn.isDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                const daemon = pluginService.pluginInstances[rootWidget.pluginId];
                                if (daemon) {
                                    daemon.toggleGroup(modelData.id);
                                } else {
                                    console.warn("[desktopWidgetToggle] Daemon not found; fallback to settings change");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
