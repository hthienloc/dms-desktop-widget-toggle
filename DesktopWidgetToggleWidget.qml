import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: rootWidget

    IpcHandler {
        target: "desktopWidgetToggle"

        function toggleGroup(groupId: string): string {
            if (!groupId) return "ERROR: No group ID provided";
            const group = rootWidget.groups.find(g => g.id === groupId || (g.name && g.name.toLowerCase() === groupId.toLowerCase()));
            if (!group) return `ERROR: Group not found: ${groupId}`;
            rootWidget.toggleGroup(group.id);
            const isActive = rootWidget.activeGroupIds.includes(group.id);
            return isActive ? `GROUP_ACTIVATED: ${group.name}` : `GROUP_DEACTIVATED: ${group.name}`;
        }

        function toggle(groupId: string): string {
            return toggleGroup(groupId);
        }

        function activate(groupId: string): string {
            if (!groupId) return "ERROR: No group ID provided";
            const group = rootWidget.groups.find(g => g.id === groupId || (g.name && g.name.toLowerCase() === groupId.toLowerCase()));
            if (!group) return `ERROR: Group not found: ${groupId}`;
            if (!rootWidget.activeGroupIds.includes(group.id)) {
                rootWidget.toggleGroup(group.id);
            }
            return `GROUP_ACTIVATED: ${group.name}`;
        }

        function deactivate(groupId: string): string {
            if (!groupId) return "ERROR: No group ID provided";
            const group = rootWidget.groups.find(g => g.id === groupId || (g.name && g.name.toLowerCase() === groupId.toLowerCase()));
            if (!group) return `ERROR: Group not found: ${groupId}`;
            if (rootWidget.activeGroupIds.includes(group.id)) {
                rootWidget.toggleGroup(group.id);
            }
            return `GROUP_DEACTIVATED: ${group.name}`;
        }

        function list(): string {
            return rootWidget.groups.map(g => `${g.id} : ${g.name} (${rootWidget.activeGroupIds.includes(g.id) ? "active" : "inactive"})`).join("\n");
        }
    }

    property var groups: pluginData.groups ?? [
        { "id": "g1", "name": "Group 1", "icon": "widgets", "widgets": [], "autoDismissDuration": 0 }
    ]
    property string conflictMode: pluginData.conflictMode ?? "single"
    property var activeGroupIds: pluginData.activeGroupIds ?? (pluginData.activeGroupId && pluginData.activeGroupId !== "" ? [pluginData.activeGroupId] : [])

    property var _groupTimers: ({})

    readonly property bool isDaemonInstance: rootWidget.parent !== null

    pluginId: "desktopWidgetToggle"
    pluginService: PluginService

    onGroupsChanged: updateAllWidgetsState(activeGroupIds)
    onActiveGroupIdsChanged: updateAllWidgetsState(activeGroupIds)

    Component.onCompleted: {
        updateAllWidgetsState(activeGroupIds)

        // Re-sync timers for already active groups if they have durations
        for (let id of activeGroupIds) {
            let duration = pluginData["autoDismissDuration_" + id] || 0;
            if (duration > 0) {
                startGroupTimer(id, duration);
            }
        }

        if (isDaemonInstance && pluginService && pluginId) {
            // Register instance for IPC
            if (!pluginService.pluginInstances[pluginId]) {
                const newInstances = Object.assign({}, pluginService.pluginInstances);
                newInstances[pluginId] = rootWidget;
                pluginService.pluginInstances = newInstances;
            }

            // Register as widget component
            if (pluginService.pluginWidgetComponents && !pluginService.pluginWidgetComponents[pluginId]) {
                const newWidgets = Object.assign({}, pluginService.pluginWidgetComponents);
                newWidgets[pluginId] = pluginService.pluginDaemonComponents[pluginId];
                pluginService.pluginWidgetComponents = newWidgets;
            }
            const plugins = pluginService.getLoadedPlugins ? pluginService.getLoadedPlugins() : [];
            const pluginInfo = plugins.find((p) => p.id === pluginId);
            if (pluginInfo)
                pluginInfo.type = "widget";
        }
    }

    Component.onDestruction: {
        // Stop all timers
        const keys = Object.keys(_groupTimers);
        for (let k of keys) {
            if (_groupTimers[k]) _groupTimers[k].stop();
        }

        if (isDaemonInstance && pluginService && pluginId) {
            if (pluginService.pluginInstances[pluginId] === rootWidget) {
                const newInstances = Object.assign({}, pluginService.pluginInstances);
                delete newInstances[pluginId];
                pluginService.pluginInstances = newInstances;
            }
        }
    }

    function startGroupTimer(groupId, seconds) {
        if (_groupTimers[groupId]) {
            _groupTimers[groupId].stop();
            _groupTimers[groupId].destroy();
        }

        const timer = Qt.createQmlObject("import QtQuick; Timer { interval: " + (seconds * 1000) + "; repeat: false; running: true }", rootWidget, "dismissTimer_" + groupId);
        timer.triggered.connect(function() {
            deactivateGroup(groupId);
            timer.destroy();
            delete _groupTimers[groupId];
        });
        _groupTimers[groupId] = timer;
    }

    function stopGroupTimer(groupId) {
        if (_groupTimers[groupId]) {
            _groupTimers[groupId].stop();
            _groupTimers[groupId].destroy();
            delete _groupTimers[groupId];
        }
    }

    function deactivateGroup(groupId) {
        if (activeGroupIds.includes(groupId)) {
            toggleGroup(groupId);
        }
    }

    function toggleGroup(groupId) {
        let currentActive = Array.isArray(activeGroupIds) ? [...activeGroupIds] : [];
        const isCurrentlyActive = currentActive.includes(groupId);
        const group = groups.find(g => g.id === groupId);

        if (conflictMode === "single") {
            // Stop all existing timers when switching in single mode
            for (let id of currentActive) stopGroupTimer(id);

            if (isCurrentlyActive) {
                currentActive = [];
            } else {
                currentActive = [groupId];
                let duration = pluginData["autoDismissDuration_" + groupId] || 0;
                if (duration > 0) {
                    startGroupTimer(groupId, duration);
                }
            }
        } else if (conflictMode === "overlap") {
            if (isCurrentlyActive) {
                currentActive = currentActive.filter(id => id !== groupId);
                stopGroupTimer(groupId);
            } else {
                if (!hasOverlapWithActive(groupId, currentActive)) {
                    currentActive.push(groupId);
                    let duration = pluginData["autoDismissDuration_" + groupId] || 0;
                    if (duration > 0) {
                        startGroupTimer(groupId, duration);
                    }
                }
            }
        } else {
            if (isCurrentlyActive) {
                currentActive = currentActive.filter(id => id !== groupId);
                stopGroupTimer(groupId);
            } else {
                currentActive.push(groupId);
                let duration = pluginData["autoDismissDuration_" + groupId] || 0;
                if (duration > 0) {
                    startGroupTimer(groupId, duration);
                }
            }
        }

        updateAllWidgetsState(currentActive);
        activeGroupIds = currentActive;

        if (pluginService) {
            pluginService.savePluginData(pluginId, "activeGroupIds", currentActive);
            pluginService.savePluginData(pluginId, "activeGroupId", currentActive.length > 0 ? currentActive[0] : "");
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
            const activeGroupsWithWidget = rootWidget.groups.filter(g => activeIds.includes(g.id) && g.widgets && g.widgets.includes(wId));
            if (activeGroupsWithWidget.length > 0) {
                SettingsData.updateDesktopWidgetInstance(wId, {
                    enabled: true
                });

                let showOnOverlayVal = false;
                let showOnOverviewVal = false;
                let showOnOverviewOnlyVal = false;
                let clickThroughVal = false;

                activeGroupsWithWidget.forEach(g => {
                    const hasOverride = !!g.overrideIndividual && g.widgetOverrides && g.widgetOverrides[wId];
                    const overrides = hasOverride ? g.widgetOverrides[wId] : {};

                    if (hasOverride) {
                        if (overrides.toggleOverlay !== false) showOnOverlayVal = true;
                        if (!!overrides.toggleOverview) showOnOverviewVal = true;
                        if (!!overrides.toggleOverviewOnly) showOnOverviewOnlyVal = true;
                        if (!!overrides.toggleClickThrough) clickThroughVal = true;
                    } else {
                        if (g.toggleOverlay !== false) showOnOverlayVal = true;
                        if (!!g.toggleOverview) showOnOverviewVal = true;
                        if (!!g.toggleOverviewOnly) showOnOverviewOnlyVal = true;
                        if (!!g.toggleClickThrough) clickThroughVal = true;
                    }
                });

                SettingsData.updateDesktopWidgetInstanceConfig(wId, {
                    showOnOverlay: showOnOverlayVal,
                    showOnOverview: showOnOverviewVal,
                    showOnOverviewOnly: showOnOverviewOnlyVal,
                    clickThrough: clickThroughVal
                });
            } else {
                SettingsData.updateDesktopWidgetInstanceConfig(wId, {
                    showOnOverlay: false,
                    showOnOverview: false,
                    showOnOverviewOnly: false,
                    clickThrough: false
                });

                const groupsWithWidget = rootWidget.groups.filter(g => g.widgets && g.widgets.includes(wId));
                const shouldHide = groupsWithWidget.some(g => {
                    const hasOverride = !!g.overrideIndividual && g.widgetOverrides && g.widgetOverrides[wId];
                    if (hasOverride) {
                        return !!g.widgetOverrides[wId].hideWhenInactive;
                    } else {
                        return !!g.hideWhenInactive;
                    }
                });

                if (shouldHide) {
                    SettingsData.updateDesktopWidgetInstance(wId, {
                        enabled: false
                    });
                } else {
                    SettingsData.updateDesktopWidgetInstance(wId, {
                        enabled: true
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
                                rootWidget.toggleGroup(modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }
}
