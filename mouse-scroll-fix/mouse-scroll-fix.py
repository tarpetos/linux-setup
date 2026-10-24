#!/usr/bin/env python3
import evdev
from evdev import UInput, ecodes as e
import time
import sys
import select
import os

# Time in seconds to ignore opposite scroll directions (debounce threshold)
DEBOUNCE_TIME = 0.15 

def get_mouse_devices():
    mice = []
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        # Skip virtual devices to prevent infinite loops
        if "virtual" in dev.name.lower() or "keyd" in dev.name.lower() or "debounced" in dev.name.lower():
            continue
        caps = dev.capabilities()
        if e.EV_REL in caps and e.REL_WHEEL in caps[e.EV_REL]:
            mice.append(dev)
    return mice

def main():
    mice = get_mouse_devices()
    if not mice:
        print("No physical mouse found.")
        sys.exit(1)

    dev_ui_map = {}
    for dev in mice:
        caps = dev.capabilities()
        # Remove EV_SYN, UInput handles it automatically
        if e.EV_SYN in caps:
            del caps[e.EV_SYN]
        
        name = f"Debounced {dev.name}"
        try:
            ui = UInput(caps, name=name, version=dev.info.version, vendor=dev.info.vendor, product=dev.info.product)
            dev.grab() # Intercept original events
        except Exception as ex:
            print(f"Failed to setup {dev.name}: {ex}")
            continue
            
        dev_ui_map[dev.path] = {
            'dev': dev,
            'ui': ui,
            'last_wheel_time': 0,
            'last_wheel_dir': 0
        }
        print(f"Debouncing {dev.name} ({dev.path})")

    if not dev_ui_map:
        print("No devices successfully setup.")
        sys.exit(1)

    try:
        devices = [d['dev'] for d in dev_ui_map.values()]
        while True:
            r, w, x = select.select(devices, [], [])
            for fd in r:
                path = fd.path
                state = dev_ui_map[path]
                ui = state['ui']
                
                try:
                    for event in fd.read():
                        if event.type == e.EV_REL and event.code == e.REL_WHEEL:
                            val = event.value
                            if val == 0: continue
                            dir = 1 if val > 0 else -1
                            now = time.time()
                            
                            if dir != state['last_wheel_dir'] and (now - state['last_wheel_time']) < DEBOUNCE_TIME:
                                # Ignore the bounce (opposite direction scroll too soon after real scroll)
                                pass
                            else:
                                state['last_wheel_dir'] = dir
                                state['last_wheel_time'] = now
                                ui.write_event(event)
                        else:
                            ui.write_event(event)
                    ui.syn()
                except OSError:
                    # Device disconnected
                    pass
    except KeyboardInterrupt:
        pass
    finally:
        for state in dev_ui_map.values():
            try:
                state['dev'].ungrab()
                state['ui'].close()
            except:
                pass

if __name__ == "__main__":
    main()
