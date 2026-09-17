import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property string configPath: Quickshell.env("SOLVERFORGE_BENCH_BAR_CONFIG") || ((Quickshell.env("HOME") || "") + "/.config/solverforge-bench-bar/config.json")
    property string stateDir: Quickshell.env("SOLVERFORGE_BENCH_BAR_STATE_DIR") || ((Quickshell.env("HOME") || "") + "/.local/state/solverforge-bench-bar")
    property string benchbarBin: Quickshell.env("SOLVERFORGE_BENCH_BAR_BIN") || "solverforge-bench-bar"
    property string snapshotPath: stateDir + "/snapshot.json"
    property string uiPath: stateDir + "/ui.json"
    property string eventPath: stateDir + "/state-event.json"
    property string textFont: "Fira Code"
    property string iconFont: "Symbols Nerd Font Mono"
    property double nowMilliseconds: Date.now()
    property real savedRunContentY: 0
    property real savedRecentContentX: 0
    property bool scrollRestorePending: false
    property var viewData: snapshotAdapter.view && snapshotAdapter.view.summary ? snapshotAdapter.view : ({
        summary: {}, headlineRun: null, currentCohort: { runs: [] }, monitorRuns: [], recentRuns: [], warehouseDriftRuns: [], source: {}
    })
    property var summary: viewData.summary || ({})
    property var headlineRun: viewData.headlineRun || null
    property var cohort: viewData.currentCohort || ({ runs: [] })
    property var monitorRuns: viewData.monitorRuns || []
    property var recentRuns: viewData.recentRuns || []
    property var source: viewData.source || ({})
    property real staleAfterSeconds: {
        var configured = Number(viewData.staleAfterSeconds || 0)
        return isNaN(configured) || configured < 1 ? 8 : configured
    }
    property bool snapshotExpired: {
        if (!snapshotAdapter.generatedAt) {
            return false
        }
        var generated = Date.parse(snapshotAdapter.generatedAt)
        return isNaN(generated) || root.nowMilliseconds - generated > root.staleAfterSeconds * 1000
    }
    property string effectiveStatus: snapshotExpired ? "stale" : (snapshotAdapter.status || "loading")

    function runBenchbar(args) {
        if (actionRunner.running) {
            return
        }

        actionRunner.command = [root.benchbarBin].concat(args).concat(["--config", root.configPath])
        actionRunner.running = true
    }

    function closeModal() {
        if (closeRunner.running) {
            return
        }

        closeRunner.command = [root.benchbarBin, "ui", "close", "--config", root.configPath]
        closeRunner.running = true
    }

    function statusColor(level) {
        if (level === "critical" || level === "source-error" || level === "failed") {
            return "#E06C75"
        }
        if (level === "warning" || level === "stalled") {
            return "#F2C572"
        }
        if (level === "stale" || level === "loading" || level === "unknown" || level === "terminal-drift") {
            return "#6A6E95"
        }
        if (level === "completed" || level === "active") {
            return "#82FB9C"
        }
        return "#85E1FB"
    }

    function runColor(run) {
        if (!run) {
            return "#6A6E95"
        }
        if (run.severity === "critical") {
            return "#E06C75"
        }
        if (run.severity === "warning") {
            return "#F2C572"
        }
        return root.statusColor(run.observedState)
    }

    function displayedRunColor(run) {
        return root.snapshotExpired ? root.statusColor("stale") : root.runColor(run)
    }

    function compactNumber(value) {
        var number = Number(value || 0)
        if (number >= 1000000) {
            return (number / 1000000).toFixed(number >= 10000000 ? 0 : 1) + "m"
        }
        if (number >= 10000) {
            return (number / 1000).toFixed(number >= 100000 ? 0 : 1) + "k"
        }
        return number.toLocaleString()
    }

    function duration(seconds) {
        var value = Math.max(0, Math.round(Number(seconds || 0)))
        if (value < 60) {
            return value + "s"
        }
        if (value < 3600) {
            return Math.floor(value / 60) + "m " + (value % 60) + "s"
        }
        return Math.floor(value / 3600) + "h " + Math.floor((value % 3600) / 60) + "m"
    }

    function elapsedSeconds(work) {
        if (!work || !work.startedAt) {
            return 0
        }
        var started = Date.parse(work.startedAt)
        return isNaN(started) ? 0 : Math.max(0, (root.nowMilliseconds - started) / 1000)
    }

    function workFraction(work) {
        var watchdog = Number(work && work.watchdogSeconds ? work.watchdogSeconds : 0)
        return watchdog > 0 ? Math.min(1, root.elapsedSeconds(work) / watchdog) : 0
    }

    function positionText(run) {
        if (!run || !run.matrixWidth) {
            return "matrix position unavailable"
        }
        return "case " + (run.currentCase || 1) + "  trial " + (Number(run.trialInCase || 0) + 1) + "/" + run.matrixWidth
    }

    function workText(run) {
        if (!run || !run.currentWork) {
            if (run && run.lastResult && run.lastResult.instance) {
                return "last  " + run.lastResult.instance + " / " + run.lastResult.solver + " / " + run.lastResult.timeLimitSeconds + "s"
            }
            return "no current solver event"
        }
        var work = run.currentWork
        return work.instance + " / " + work.solver + " / " + work.timeLimitSeconds + "s"
    }

    function issueText(run) {
        var counters = run && run.counters ? run.counters : ({})
        return "run errors " + (counters.runErrors || 0) +
            "   watchdog " + (counters.watchdogKills || 0) +
            "   validation " + (counters.validationErrors || 0) +
            "   infeasible " + (counters.infeasible || 0) +
            "   fair-start " + (counters.fairStartFailures || 0) +
            "   wall-time " + (counters.wallTimeViolations || 0)
    }

    function cohortLabel() {
        var total = root.cohort && root.cohort.runs ? root.cohort.runs.length : 0
        if (!total) {
            return "No nightly cohort in cache"
        }
        return (root.cohort.completedCount || 0) + "/" + total + " suites completed"
    }

    function generatedLabel() {
        if (!snapshotAdapter.generatedAt) {
            return "waiting for cached data"
        }
        return (root.snapshotExpired ? "stale cache " : "snapshot ") + snapshotAdapter.generatedAt.replace("T", " ").replace("Z", " UTC")
    }

    Process {
        id: actionRunner
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length) {
                    console.log(text.trim())
                }
            }
        }
    }

    Process {
        id: closeRunner
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length) {
                    console.log(text.trim())
                }
            }
        }
    }

    FileView {
        id: snapshotFile
        path: root.snapshotPath
        watchChanges: false

        JsonAdapter {
            id: snapshotAdapter
            property int snapshotVersion: 0
            property string generatedAt: ""
            property string status: "loading"
            property var source: ({})
            property var runs: []
            property var recentRuns: []
            property var summary: ({})
            property var view: ({})
        }
    }

    FileView {
        id: uiFile
        path: root.uiPath
        watchChanges: false

        JsonAdapter {
            id: uiAdapter
            property bool open: false
            property string requestedAt: ""
        }
    }

    FileView {
        id: eventFile
        path: root.eventPath
        watchChanges: true
        onFileChanged: root.reloadState(true)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.nowMilliseconds = Date.now()
    }

    Timer {
        id: scrollRestoreTimer
        interval: 0
        repeat: false
        onTriggered: {
            root.restoreScrollPositions()
            root.scrollRestorePending = false
        }
    }

    function captureScrollPositions() {
        root.savedRunContentY = runList.contentY
        root.savedRecentContentX = recentList.contentX
    }

    function restoreScrollPositions() {
        var minimumY = runList.originY
        var maximumY = Math.max(minimumY, runList.originY + runList.contentHeight - runList.height)
        runList.contentY = Math.max(minimumY, Math.min(root.savedRunContentY, maximumY))

        var minimumX = recentList.originX
        var maximumX = Math.max(minimumX, recentList.originX + recentList.contentWidth - recentList.width)
        recentList.contentX = Math.max(minimumX, Math.min(root.savedRecentContentX, maximumX))
    }

    function reloadState(preserveScroll) {
        if (preserveScroll && !root.scrollRestorePending) {
            root.captureScrollPositions()
            root.scrollRestorePending = true
        }
        snapshotFile.reload()
        uiFile.reload()
        if (preserveScroll) {
            scrollRestoreTimer.restart()
        }
    }

    Component.onCompleted: {
        eventFile.reload()
        root.reloadState(false)
    }

    component MetricTile: Rectangle {
        property string label: ""
        property string value: ""
        property string detail: ""
        property color accent: "#82FB9C"

        Layout.fillWidth: true
        Layout.preferredHeight: 70
        color: "#10131F"
        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.45)
        border.width: 1
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: label.toUpperCase()
                color: "#6A6E95"
                font.family: root.textFont
                font.pixelSize: 9
                font.bold: true
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: value
                    color: accent
                    font.family: root.textFont
                    font.pixelSize: 23
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBottom
                    text: detail
                    color: "#9AA4BE"
                    font.family: root.textFont
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }
        }
    }

    component ActionButton: Rectangle {
        signal clicked()
        property string icon: ""
        property string label: ""
        property color accent: "#82FB9C"

        Layout.preferredWidth: 112
        Layout.preferredHeight: 38
        color: buttonArea.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.14) : "#151927"
        border.color: buttonArea.containsMouse ? accent : "#2E344A"
        border.width: 1
        radius: 0

        Behavior on color {
            ColorAnimation { duration: 110 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 110 }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: icon
                color: accent
                font.family: root.iconFont
                font.pixelSize: 15
            }

            Text {
                text: label
                color: "#DDF7FF"
                font.family: root.textFont
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component StateBadge: Rectangle {
        property string label: "unknown"
        property color accent: root.statusColor(label)

        implicitWidth: badgeText.implicitWidth + 20
        implicitHeight: 24
        color: Qt.rgba(accent.r, accent.g, accent.b, 0.11)
        border.color: accent
        border.width: 1
        radius: 0

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: label
            color: accent
            font.family: root.textFont
            font.pixelSize: 9
            font.bold: true
        }
    }

    component CohortPill: Rectangle {
        property var run: null
        property color accent: root.runColor(run)

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        color: "#151927"
        border.color: accent
        border.width: 1
        radius: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 7
                Layout.preferredHeight: 7
                radius: 0
                color: accent
            }

            Text {
                Layout.fillWidth: true
                text: run ? (run.benchmarkLabel || run.benchmarkName || "suite") : "suite"
                color: "#DDF7FF"
                font.family: root.textFont
                font.pixelSize: 10
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                text: run ? (run.observedState || run.warehouseStatus || "unknown") : "unknown"
                color: accent
                font.family: root.textFont
                font.pixelSize: 9
            }
        }
    }

    PanelWindow {
        id: modal
        visible: uiAdapter.open
        screen: Quickshell.screens.length ? Quickshell.screens[0] : null
        implicitWidth: screen ? screen.width : 1200
        implicitHeight: screen ? screen.height : 820
        color: "transparent"
        focusable: true
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins {
            top: 0
            bottom: 0
            left: 0
            right: 0
        }

        onVisibleChanged: {
            if (visible) {
                modalFade.restart()
            }
        }

        NumberAnimation {
            id: modalFade
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }

        Shortcut {
            sequence: "Esc"
            context: Qt.WindowShortcut
            onActivated: root.closeModal()
        }

        Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: "#050711"
                opacity: 0.72
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeModal()
            }

            Rectangle {
                anchors.centerIn: parent
                width: card.width + 10
                height: card.height + 10
                radius: 0
                color: Qt.rgba(0, 0, 0, 0.22)
            }

            Rectangle {
                anchors.centerIn: parent
                width: card.width + 4
                height: card.height + 4
                radius: 0
                color: Qt.rgba(0, 0, 0, 0.34)
            }

            Rectangle {
                id: card
                width: Math.min(1120, Math.max(360, modal.width - 36))
                height: Math.min(900, Math.max(560, modal.height - 32))
                anchors.centerIn: parent
                color: "#0B0C16"
                border.color: root.statusColor(root.effectiveStatus)
                border.width: 1
                radius: 0

                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse.accepted = true
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 0
                    color: "transparent"
                    border.color: "#26304A"
                    border.width: 1
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            color: "#111827"
                            border.color: "#82FB9C"
                            border.width: 1
                            radius: 0

                            Canvas {
                                anchors.fill: parent
                                anchors.margins: 7

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.strokeStyle = "#26304A"
                                    ctx.lineWidth = 1.5
                                    ctx.beginPath()
                                    ctx.moveTo(3, height - 4)
                                    ctx.lineTo(width - 2, height - 4)
                                    ctx.moveTo(4, height - 3)
                                    ctx.lineTo(4, 3)
                                    ctx.stroke()

                                    var bars = [0.34, 0.58, 0.46, 0.78]
                                    for (var i = 0; i < bars.length; i++) {
                                        var barWidth = 4
                                        var x = 8 + (i * 6)
                                        var barHeight = (height - 10) * bars[i]
                                        ctx.fillStyle = i === bars.length - 1 ? "#85E1FB" : "#82FB9C"
                                        ctx.fillRect(x, height - 5 - barHeight, barWidth, barHeight)
                                    }

                                    ctx.strokeStyle = "#F2C572"
                                    ctx.lineWidth = 1.5
                                    ctx.beginPath()
                                    ctx.moveTo(7, height * 0.62)
                                    ctx.lineTo(14, height * 0.45)
                                    ctx.lineTo(21, height * 0.53)
                                    ctx.lineTo(29, height * 0.21)
                                    ctx.stroke()
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: "solverforge-bench-bar"
                                color: "#DDF7FF"
                                font.family: root.textFont
                                font.pixelSize: 24
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "read-only warehouse + run-log monitor   " + root.generatedLabel()
                                color: "#9CF7C2"
                                font.family: root.textFont
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        StateBadge {
                            label: root.effectiveStatus
                            accent: root.statusColor(label)
                        }

                        ActionButton {
                            icon: ""
                            label: "Refresh"
                            onClicked: root.runBenchbar(["refresh"])
                        }

                        ActionButton {
                            icon: ""
                            label: "Close"
                            accent: "#85E1FB"
                            onClicked: root.closeModal()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        MetricTile {
                            label: "observed active"
                            value: String(summary.activeCount || 0)
                            detail: (summary.operationalCandidateCount || 0) + " live candidates"
                        }

                        MetricTile {
                            label: "nightly cohort"
                            value: (summary.cohortCompletedCount || 0) + "/" + (summary.cohortSuiteCount || 0)
                            detail: (summary.cohortActiveCount || 0) + " active"
                            accent: "#85E1FB"
                        }

                        MetricTile {
                            label: "persisted rows"
                            value: root.compactNumber(summary.runningRows || 0)
                            detail: "running candidates"
                            accent: "#C79CF7"
                        }

                        MetricTile {
                            label: "attention"
                            value: String(summary.attentionRunCount || 0)
                            detail: root.compactNumber(summary.issueResultCount || 0) + " result flags   " + (summary.warehouseDriftCount || 0) + " stale rows"
                            accent: (summary.attentionRunCount || 0) > 0 ? "#F2C572" : "#82FB9C"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: cohortColumn.implicitHeight + 20
                        color: "#0F1320"
                        border.color: "#242B40"
                        border.width: 1
                        radius: 0

                        ColumnLayout {
                            id: cohortColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 7

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: "CURRENT NIGHTLY COHORT"
                                    color: "#6A6E95"
                                    font.family: root.textFont
                                    font.pixelSize: 9
                                    font.bold: true
                                }

                                Text {
                                    text: root.cohortLabel()
                                    color: "#9AA4BE"
                                    font.family: root.textFont
                                    font.pixelSize: 9
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.cohort.runs || []
                                    CohortPill {
                                        run: modelData
                                    }
                                }

                                Text {
                                    visible: !(root.cohort.runs && root.cohort.runs.length)
                                    Layout.fillWidth: true
                                    text: "No cohort data is available in the current snapshot."
                                    color: "#6A6E95"
                                    font.family: root.textFont
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 240
                        color: "#0F1320"
                        border.color: "#242B40"
                        border.width: 1
                        radius: 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: "RUN MONITOR"
                                    color: "#DDF7FF"
                                    font.family: root.textFont
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Text {
                                    text: (summary.activeCount || 0) + " active   " + (summary.attentionRunCount || 0) + " attention"
                                    color: "#6A6E95"
                                    font.family: root.textFont
                                    font.pixelSize: 9
                                }
                            }

                            ListView {
                                id: runList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: root.monitorRuns
                                clip: true
                                spacing: 8
                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: ListView.view.width
                                    height: 136
                                    color: index % 2 === 0 ? "#151927" : "#10131F"
                                    border.color: root.displayedRunColor(modelData)
                                    border.width: 1
                                    radius: 0

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 11

                                        Rectangle {
                                            Layout.preferredWidth: 7
                                            Layout.fillHeight: true
                                            color: root.displayedRunColor(modelData)
                                            radius: 0
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 5

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.benchmarkLabel || modelData.benchmarkName || "benchmark"
                                                    color: "#DDF7FF"
                                                    font.family: root.textFont
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                StateBadge {
                                                    label: root.snapshotExpired ? "cached " + (modelData.observedState || "unknown") : (modelData.observedState || "unknown")
                                                    accent: root.displayedRunColor(modelData)
                                                }

                                                Text {
                                                    text: root.compactNumber(modelData.resultCount || 0) + " rows   " + (modelData.shortId || "")
                                                    color: "#85E1FB"
                                                    font.family: root.textFont
                                                    font.pixelSize: 10
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 12

                                                Text {
                                                    text: root.positionText(modelData)
                                                    color: "#9CF7C2"
                                                    font.family: root.textFont
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: root.workText(modelData)
                                                    color: modelData.currentWork ? "#DDF7FF" : "#6A6E95"
                                                    font.family: root.textFont
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    visible: !!modelData.currentWork
                                                    text: modelData.currentWork ? (root.duration(root.elapsedSeconds(modelData.currentWork)) + " / " + root.duration(modelData.currentWork.watchdogSeconds || 0)) : ""
                                                    color: root.workFraction(modelData.currentWork) > 0.85 ? "#F2C572" : "#85E1FB"
                                                    font.family: root.textFont
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 8
                                                color: "#090B12"
                                                border.color: "#252B3F"
                                                border.width: 1
                                                radius: 0

                                                Rectangle {
                                                    id: workFill
                                                    width: parent.width * (modelData.currentWork ? root.workFraction(modelData.currentWork) : 0)
                                                    height: parent.height
                                                    radius: 0
                                                    property color fillColor: root.snapshotExpired ? root.statusColor("stale") : (root.workFraction(modelData.currentWork) > 0.85 ? "#F2C572" : root.runColor(modelData))

                                                    Behavior on width {
                                                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                                                    }

                                                    gradient: Gradient {
                                                        GradientStop { position: 0.0; color: Qt.lighter(workFill.fillColor, 1.18) }
                                                        GradientStop { position: 1.0; color: workFill.fillColor }
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.issueText(modelData)
                                                color: (modelData.attentionCount || 0) > 0 ? "#F2C572" : "#6A6E95"
                                                font.family: root.textFont
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: modelData.log && (modelData.log.terminalMessage || modelData.log.error)
                                                Layout.fillWidth: true
                                                text: modelData.log ? (modelData.log.terminalMessage || modelData.log.error || "") : ""
                                                color: "#E06C75"
                                                font.family: root.textFont
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.monitorRuns.length === 0
                                    text: source.status === "error" ? (source.error || "warehouse source unavailable") : "No benchmark run is active."
                                    color: source.status === "error" ? "#E06C75" : "#6A6E95"
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: "RECENT TERMINAL RUNS"
                                color: "#6A6E95"
                                font.family: root.textFont
                                font.pixelSize: 9
                                font.bold: true
                            }

                            Text {
                                text: (summary.recentFailureCount || 0) + " recent failures"
                                color: (summary.recentFailureCount || 0) > 0 ? "#E06C75" : "#6A6E95"
                                font.family: root.textFont
                                font.pixelSize: 9
                            }
                        }

                        ListView {
                            id: recentList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            orientation: ListView.Horizontal
                            model: root.recentRuns
                            clip: true
                            spacing: 8

                            delegate: Rectangle {
                                required property var modelData
                                width: 236
                                height: 48
                                color: "#10131F"
                                border.color: root.statusColor(modelData.warehouseStatus || "unknown")
                                border.width: 1
                                radius: 0

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 6
                                        Layout.preferredHeight: 6
                                        radius: 0
                                        color: root.statusColor(modelData.warehouseStatus || "unknown")
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.benchmarkLabel || modelData.benchmarkName || "benchmark"
                                            color: "#DDF7FF"
                                            font.family: root.textFont
                                            font.pixelSize: 9
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (modelData.warehouseStatus || "unknown") + "   " + root.compactNumber(modelData.resultCount || 0) + " rows"
                                            color: root.statusColor(modelData.warehouseStatus || "unknown")
                                            font.family: root.textFont
                                            font.pixelSize: 8
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
