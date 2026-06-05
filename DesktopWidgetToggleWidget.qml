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
    property string conflictMode: pluginData.conflictMode ?? "single"
    property var activeGroupIds: pluginData.activeGroupIds ?? (pluginData.activeGroupId && pluginData.activeGroupId !== "" ? [pluginData.activeGroupId] : [])
    property int autoDismissDuration: pluginData.autoDismissDuration ?? 0
    property bool hideWhenInactive: pluginData.hideWhenInactive ?? false

    onHideWhenInactiveChanged: {
        const allWidgetIds = getAllGroupWidgetIds();
        allWidgetIds.forEach(wId => {
            const isWidgetActive = groups.some(g => activeGroupIds.includes(g.id) && g.widgets && g.widgets.includes(wId));
            if (!isWidgetActive) {
                SettingsData.updateDesktopWidgetInstance(wId, {
                    enabled: !hideWhenInactive
                });
            }
        });
    }

    Timer {
        id: dismissTimer
        interval: rootWidget.autoDismissDuration * 1000
        repeat: false
        running: false
        onTriggered: {
            if (rootWidget.activeGroupIds.length > 0) {
                rootWidget.updateAllWidgetsState([]);
                rootWidget.activeGroupIds = [];
                if (pluginService) {
                    pluginService.savePluginData(pluginId, "activeGroupIds", []);
                    pluginService.savePluginData(pluginId, "activeGroupId", "");
                }
            }
        }
    }

    function toggleGroup(groupId) {
        let currentActive = Array.isArray(activeGroupIds) ? [...activeGroupIds] : [];
        const isCurrentlyActive = currentActive.includes(groupId);

        if (conflictMode === "single") {
            if (isCurrentlyActive) {
                currentActive = [];
            } else {
                currentActive = [groupId];
            }
        } else if (conflictMode === "overlap") {
            if (isCurrentlyActive) {
                currentActive = currentActive.filter(id => id !== groupId);
            } else {
                if (!hasOverlapWithActive(groupId, currentActive)) {
                    currentActive.push(groupId);
                }
            }
        } else {
            if (isCurrentlyActive) {
                currentActive = currentActive.filter(id => id !== groupId);
            } else {
                currentActive.push(groupId);
            }
        }

        updateAllWidgetsState(currentActive);
        activeGroupIds = currentActive;

        if (pluginService) {
            pluginService.savePluginData(pluginId, "activeGroupIds", currentActive);
            pluginService.savePluginData(pluginId, "activeGroupId", currentActive.length > 0 ? currentActive[0] : "");
        }

        if (rootWidget.autoDismissDuration > 0 && currentActive.length > 0) {
            dismissTimer.restart();
        } else {
            dismissTimer.stop();
        }
    }

    function groupsOverlap(g1, g2) {
        if (!g1 || !g1.widgets || !g2 || !g2.widgets) return false;
        return g1.widgets.some(wId => g2.widgets.includes(wId));
    }

    function hasOverlapWithActive(groupId, activeIds) {
        const targetGroup = groups.find(g => g.id === groupId);
        if (!targetGroup) return false;
        for (let i = 0; i < activeIds.length; i++) {
            const activeGroup = groups.find(g => g.id === activeIds[i]);
            if (activeGroup && groupsOverlap(targetGroup, activeGroup)) {
                return true;
            }
        }
        return false;
    }

    function getAllGroupWidgetIds() {
        let ids = [];
        groups.forEach(g => {
            if (g.widgets) {
                g.widgets.forEach(wId => {
                    if (!ids.includes(wId)) {
                        ids.push(wId);
                    }
                });
            }
        });
        return ids;
    }

    function updateAllWidgetsState(activeIds) {
        const allWidgetIds = getAllGroupWidgetIds();
        allWidgetIds.forEach(wId => {
            const isWidgetActive = groups.some(g => activeIds.includes(g.id) && g.widgets && g.widgets.includes(wId));
            if (isWidgetActive) {
                SettingsData.updateDesktopWidgetInstance(wId, {
                    enabled: true
                });
                SettingsData.updateDesktopWidgetInstanceConfig(wId, {
                    showOnOverlay: true
                });
            } else {
                SettingsData.updateDesktopWidgetInstanceConfig(wId, {
                    showOnOverlay: false
                });
                if (rootWidget.hideWhenInactive) {
                    SettingsData.updateDesktopWidgetInstance(wId, {
                        enabled: false
                    });
                }
            }
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

                        readonly property bool isActive: rootWidget.activeGroupIds.includes(modelData.id)
                        readonly property bool isDisabled: {
                            if (isActive) return false;
                            if (rootWidget.conflictMode === "single") {
                                return rootWidget.activeGroupIds.length > 0;
                            }
                            if (rootWidget.conflictMode === "overlap") {
                                return rootWidget.hasOverlapWithActive(modelData.id, rootWidget.activeGroupIds);
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

                        readonly property bool isActive: rootWidget.activeGroupIds.includes(modelData.id)
                        readonly property bool isDisabled: {
                            if (isActive) return false;
                            if (rootWidget.conflictMode === "single") {
                                return rootWidget.activeGroupIds.length > 0;
                            }
                            if (rootWidget.conflictMode === "overlap") {
                                return rootWidget.hasOverlapWithActive(modelData.id, rootWidget.activeGroupIds);
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
