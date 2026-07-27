-- Minimal compositor used only to host the login greeter. Once the
-- greeter authenticates and hands off to the real session (see
-- quickshell/greeter/shell.qml), this Hyprland instance has to exit so
-- greetd can start the user's session on the same VT/seat.

-- ASUS TUF VG34VQL1B: 3440x1440, FreeSync Premium up to 165Hz over DisplayPort.
-- Its VA panel has a widely-reported brightness/gamma flicker when VRR is
-- active during normal desktop use (visible on mouse movement, and reported
-- on both Hyprland and KWin, so it is the panel, not the compositor). vrr=2
-- restricts adaptive sync to fullscreen content (games, video) and runs the
-- desktop at a fixed 165Hz, where the flicker is most noticeable. Drop to
-- vrr=0 or to 144Hz if fullscreen content still flickers.
hl.monitor({
    output = "",
    mode = "3440x1440@165",
    position = "auto",
    scale = "auto",
    vrr = 2,
})

-- Exit only after a successful Quickshell session. If QML cannot start,
-- leave this compositor alive instead of making greetd restart it in a loop.
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -p /etc/greetd/quickshell/greeter && hyprctl dispatch exit")
end)

-- The greeter session is short-lived, so its /run/user log disappears.
-- Mirror its complete Hyprland log to this boot's system journal.
hl.config({
    debug = {
        disable_logs = false,
        enable_stdout_logs = true,
        -- colored_stdout_logs = false,
    },
})
