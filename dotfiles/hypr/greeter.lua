-- Minimal compositor used only to host the login greeter. Once the
-- greeter authenticates and hands off to the real session (see
-- quickshell/greeter/shell.qml), this Hyprland instance has to exit so
-- greetd can start the user's session on the same VT/seat.

-- ASUS TUF VG34VQL1B: 3440x1440, matching the user session (see hyprland.lua).
hl.monitor({
    output   = "",
    mode     = "3440x1440@165",
    position = "auto",
    scale    = "auto",
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
