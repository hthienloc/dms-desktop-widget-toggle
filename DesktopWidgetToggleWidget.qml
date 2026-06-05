pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: rootWidget

    property var groups: pluginData.groups ?? [
        { "id": "g1", "name": "Group 1", "icon": "widgets", "widgets": [] }
    ]
    property string activeGroupId: pluginData.activeGroupId ?? ""

    function toggleGroup(groupId) {
        if (activeGroupId === groupId) {
            setGroupOverlay(groupId, false);
            activeGroupId = "";
            if (pluginService)
                pluginService.savePluginData(pluginId, "activeGroupId", "");
        } else {
            if (activeGroupId !== "") {
                setGroupOverlay(activeGroupId, false);
            }
            setGroupOverlay(groupId, true);
            activeGroupId = groupId;
            if (pluginService)
                pluginService.savePluginData(pluginId, "activeGroupId", groupId);
        }
    }

    function setGroupOverlay(groupId, showOverlay) {
        const group = groups.find(g => g.id === groupId);
        if (!group || !group.widgets)
            return;

        group.widgets.forEach(wId => {
            SettingsData.updateDesktopWidgetInstanceConfig(wId, {
                showOnOverlay: showOverlay
            });
        });
    }

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

                        readonly property bool isActive: rootWidget.activeGroupId === modelData.id
                        readonly property bool isDisabled: rootWidget.activeGroupId !== "" && rootWidget.activeGroupId !== modelData.id

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
                                rootWidget.toggleGroup(modelData.id);
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

                        readonly property bool isActive: rootWidget.activeGroupId === modelData.id
                        readonly property bool isDisabled: rootWidget.activeGroupId !== "" && rootWidget.activeGroupId !== modelData.id

                        color: isActive ? Theme.primary : (isDisabled ? Theme.surfaceContainerLow : Theme.surfaceContainerHigh)
                        opacity: isDisabled ? 0.4 : 1.0

                        DankIcon {
                            name: modelData.icon || "widgets"
                            size: Theme.barIconSize(rootWidget.barThickness, -4, rootWidget.barConfig?.maximizeWidgetIcons, rootWidget.barConfig?.iconScale)
                            color: btn.isActive ? Theme.onPrimary : Theme.surfaceText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !btn.isDisabled
                            cursorShape: btn.isDisabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                rootWidget.toggleGroup(modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }
}
