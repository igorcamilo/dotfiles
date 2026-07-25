import Quickshell
import Quickshell.Wayland

ShellRoot {
    LockContext {
        id: lockContext

        onUnlocked: {
            // Unlock before quitting, or the compositor shows a
            // fallback lock screen that can't be interacted with.
            lock.locked = false;
            Qt.quit();
        }
    }

    WlSessionLock {
        id: lock

        locked: true

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: lockContext
            }
        }
    }
}
