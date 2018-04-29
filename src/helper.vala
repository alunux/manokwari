[DBus (name="org.freedesktop.DBus")]
public interface DBusService : Object
{
    public abstract string[] list_names() throws IOError;
    public signal void name_owner_changed(string name, string old_owner, string new_owner);
}

[DBus (name="org.mpris.MediaPlayer2")]
public interface MprisIface : Object
{
    public abstract async void raise() throws IOError;
    public abstract async void quit() throws IOError;

    public abstract bool can_quit { get; set; }
    public abstract bool can_raise { get; }
}

[DBus (name="org.mpris.MediaPlayer2.Player")]
public interface PlayerIface : MprisIface
{
    public abstract async void next() throws IOError;
    public abstract async void previous() throws IOError;
    public abstract async void pause() throws IOError;
    public abstract async void play_pause() throws IOError;
    public abstract async void stop() throws IOError;
    public abstract async void play() throws IOError;

    public abstract string playback_status { owned get; }
    public abstract string loop_status { owned get; set; }
}

namespace Helper {
    public bool launch_search () {
        try {
            GLib.Process.spawn_command_line_async ("synapse");
            return true;
        } catch (Error e) {
            return false;
        }
    }

    public bool launch_profile () {
        try {
            GLib.Process.spawn_command_line_async ("gnome-about-me");
            return true;
        } catch (Error e) {
            return false;
        }
    }

    public bool lock_screen () {
        try {
            GLib.Process.spawn_command_line_async ("gnome-screensaver-command -l");
            return true;
        } catch (Error e) {
            return false;
        }
    }

    public bool print_screen () {
        try {
            GLib.Process.spawn_command_line_async ("gnome-screenshot -i");
            return true;
        } catch (Error e) {
            stderr.printf("Error running print_screen %s\n", e.message);
            return false;
        }
    }

    public void grab (Gtk.Window w) {
        var device = Gtk.get_current_event_device();

        if (device == null) {
            var display = w.get_display ();
            var manager = display.get_device_manager ();
            var devices = manager.list_devices (Gdk.DeviceType.MASTER).copy();
            device = devices.data;
        }
        var keyboard = device;
        var pointer = device;

        if (device.get_source() == Gdk.InputSource.KEYBOARD) {
            pointer = device.get_associated_device ();
        } else {
            keyboard = device.get_associated_device ();
        }

        var status = keyboard.grab(w.get_window(), Gdk.GrabOwnership.WINDOW, true, Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK, null, Gdk.CURRENT_TIME);
        status = pointer.grab(w.get_window(), Gdk.GrabOwnership.WINDOW, true, Gdk.EventMask.BUTTON_PRESS_MASK, null, Gdk.CURRENT_TIME);
    }

    public void ungrab (Gtk.Window w) {
        var device = Gtk.get_current_event_device();
        var secondary = device.get_associated_device();
        device.ungrab(Gdk.CURRENT_TIME);
        secondary.ungrab(Gdk.CURRENT_TIME);
    }

    public static string get_icon_path (string name, int size=24) {
        var icon = Gtk.IconTheme.get_default ();
        var i = icon.lookup_icon (name, size, Gtk.IconLookupFlags.GENERIC_FALLBACK);
        if (i != null) {
            return i.get_filename();
        } else {
            return name;
        }
    }

    public static JSCore.Value js_run_desktop (JSCore.Context ctx,
            JSCore.Object function,
            JSCore.Object thisObject,
            JSCore.Value[] arguments,
            out JSCore.Value exception) {

        exception = null;
        if (arguments.length > 0) {
            bool from_desktop = false;
            // Optional argument takes a boolean value
            // to indicate whether this should be taken
            // from user's desktop directory
            if (arguments.length > 1) {
                var _from_desktop = arguments [1].to_boolean (ctx);
                from_desktop = _from_desktop;
            }

            var s = arguments [0].to_string_copy (ctx, null);
            char[] buffer = new char[s.get_length() + 1];
            s.get_utf8_c_string (buffer, buffer.length);
            string path = null;

            // Check whether the desktop has an absolute path or not
            if (buffer [0] != '/') {
                // If not, append the correct path
                if (from_desktop) {
                    path = Environment.get_user_special_dir (UserDirectory.DESKTOP) + "/" + (string) buffer;
                } else {
                    path = "/usr/share/applications/" + (string) buffer;
                }
            } else {
                // Otherwise take it as is
                path = (string) buffer;
            }
            var info = new GLib.DesktopAppInfo.from_filename (path);
            try {
                info.launch (null, Gdk.Display.get_default ().get_app_launch_context ());
            } catch (Error e) {
                var dialog = new Gtk.MessageDialog (null, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE, _("Error opening menu item %s: %s"), info.get_display_name (), e.message);
                dialog.response.connect (() => {
                            dialog.destroy ();
                        });
                dialog.show ();
            }
        }

        return new JSCore.Value.undefined (ctx);
    }

    public static JSCore.Value js_open_uri (JSCore.Context ctx,
            JSCore.Object function,
            JSCore.Object thisObject,
            JSCore.Value[] arguments,
            out JSCore.Value exception) {

        exception = null;
        if (arguments.length == 1) {
            var s = arguments [0].to_string_copy (ctx, null);
            char buffer[1024];
            s.get_utf8_c_string (buffer, buffer.length);
            try {
                Gtk.show_uri (Gdk.Screen.get_default (), (string) buffer, Gtk.get_current_event_time());
            } catch (Error e) {
                var dialog = new Gtk.MessageDialog (null, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE, _("Error opening menu item '%s': %s"), (string) buffer, e.message);
                dialog.response.connect (() => {
                            dialog.destroy ();
                        });
                dialog.show ();
            }
        }

        return new JSCore.Value.undefined (ctx);
    }


    public static JSCore.Value js_run_command (JSCore.Context ctx,
            JSCore.Object function,
            JSCore.Object thisObject,
            JSCore.Value[] arguments,
            out JSCore.Value exception) {

        exception = null;
        if (arguments.length == 1) {
            var s = arguments [0].to_string_copy (ctx, null);
            char buffer[1024];
            s.get_utf8_c_string (buffer, buffer.length);
            try {
                var app = AppInfo.create_from_commandline ((string) buffer, (string) buffer, AppInfoCreateFlags.NONE);
                app.launch (null, null);
            } catch (Error e) {
                var dialog = new Gtk.MessageDialog (null, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE, _("Error running command '%s': %s"), (string) buffer, e.message);
                dialog.response.connect (() => {
                            dialog.destroy ();
                        });
                dialog.show ();
            }
        }

        return new JSCore.Value.undefined (ctx);
    }

    public static JSCore.Value js_translate (JSCore.Context ctx,
            JSCore.Object function,
            JSCore.Object thisObject,
            JSCore.Value[] arguments,
            out JSCore.Value exception) {

        exception = null;
        if (arguments.length == 1) {
            var s = arguments [0].to_string_copy (ctx, null);
            char[] buffer = new char[s.get_length() + 1];
            s.get_utf8_c_string (buffer, buffer.length);

            s = new JSCore.String.with_utf8_c_string (_((string) buffer));
            var result = new JSCore.Value.string (ctx, s);
            s = null;
            buffer = null;
            return result;
        }

        return new JSCore.Value.undefined (ctx);
    }

    public static JSCore.Value js_get_icon_path (JSCore.Context ctx,
            JSCore.Object function,
            JSCore.Object thisObject,
            JSCore.Value[] arguments,
            out JSCore.Value exception) {

        exception = null;
        if (arguments.length > 0) {
            var s = arguments [0].to_string_copy (ctx, null);
            char[] buffer = new char[s.get_length() + 1];
            s.get_utf8_c_string (buffer, buffer.length);

            int size = 24;
            if (arguments.length > 1) {
                var size_d = arguments [1].to_number (ctx, null);
                size = (int) size_d;            
            }

            s = new JSCore.String.with_utf8_c_string (get_icon_path((string) buffer, size));
            var result = new JSCore.Value.string (ctx, s);
            s = null;
            buffer = null;
            return result;
        }

        return new JSCore.Value.undefined (ctx);
    }

    public static JSCore.Value js_get_time (JSCore.Context ctx,
            JSCore.Object function,
            JSCore.Object thisObject,
            JSCore.Value[] arguments,
            out JSCore.Value exception) {

        exception = null;
		char bufferClock[100];
		Time t = Time.local (time_t ());
		t.strftime (bufferClock, _("%H:%M"));

        var s = new JSCore.String.with_utf8_c_string (_((string) bufferClock));
        var result = new JSCore.Value.string (ctx, s);
        s = null;
        return result;
    }

    public static JSCore.Value js_get_date (JSCore.Context ctx,
            JSCore.Object function,
            JSCore.Object thisObject,
            JSCore.Value[] arguments,
            out JSCore.Value exception) {

        exception = null;
		char bufferClock[100];
		Time t = Time.local (time_t ());
		t.strftime (bufferClock, _("%A, %B %e %Y"));

        var s = new JSCore.String.with_utf8_c_string (_((string) bufferClock));
        var result = new JSCore.Value.string (ctx, s);
        s = null;
        return result;
    }

    public static void on_name_owner_changed(string? n, string? owner, string? new_owner)
    {
        if (!n.has_prefix("org.mpris.MediaPlayer2.")) {
            return;
        }

        if (owner == "") {
            print("new player: %s\n", n);
            print("owner: %s\n", new_owner);
        } else {
            Idle.add(()=> {
                print("player exited: %s\n", n);
                print("owner: %s\n", owner);
                return false;
            });
        }
    }

    public static JSCore.Value js_media_control (JSCore.Context ctx,
            JSCore.Object function,
            JSCore.Object thisObject,
            JSCore.Value[] arguments,
            out JSCore.Value exception) {

        exception = null;
        if (arguments.length == 1) {
            DBusService impl;
            PlayerIface? player = null;
            var s = arguments [0].to_string_copy (ctx, null);
            char buffer[1024];
            s.get_utf8_c_string (buffer, buffer.length);
            try {
                impl = Bus.get_proxy_sync(BusType.SESSION, "org.freedesktop.DBus", "/org/freedesktop/DBus");
                var names = impl.list_names();

                foreach (var name in names) {
                    if (name.has_prefix("org.mpris.MediaPlayer2.")) {
                        try {
                            player = Bus.get_proxy_sync(BusType.SESSION, name, "/org/mpris/MediaPlayer2");
                            if ((string)buffer == "play") {
                                player.play();
                            } else if ((string)buffer == "pause") {
                                player.pause();
                            } else if ((string)buffer == "prev") {
                                player.previous();
                            } else if ((string)buffer == "next") {
                                player.next();
                            } else if ((string)buffer == "stop") {
                                player.stop();
                            }
                            break;
                        } catch (Error e) {
                            print(e.message);
                        }
                    }
                }

                impl.name_owner_changed.connect(on_name_owner_changed);
            } catch (Error e) {
                print("Failed to initialise dbus: %s", e.message);
            }
        }

        return new JSCore.Value.undefined (ctx);
    }

    const JSCore.StaticFunction[] js_funcs = {
        { "run_desktop", js_run_desktop, JSCore.PropertyAttribute.ReadOnly },
        { "open_uri", js_open_uri, JSCore.PropertyAttribute.ReadOnly },
        { "run_command", js_run_command, JSCore.PropertyAttribute.ReadOnly },
        { "translate", js_translate, JSCore.PropertyAttribute.ReadOnly },
        { "getIconPath", js_get_icon_path, JSCore.PropertyAttribute.ReadOnly },
        { "getTime", js_get_time, JSCore.PropertyAttribute.ReadOnly },
        { "getDate", js_get_date, JSCore.PropertyAttribute.ReadOnly },
        { "media_control", js_media_control, JSCore.PropertyAttribute.ReadOnly },
        { null, null, 0 }
    };


    const JSCore.ClassDefinition js_class = {
        0,
        JSCore.ClassAttribute.None,
        "Utils",
        null,

        null,
        js_funcs,

        null,
        null,

        null,
        null,
        null,
        null,

        null,
        null,
        null,
        null,
        null
    };

    public static void setup_js_class (JSCore.GlobalContext context) {
        var c = new JSCore.Class (js_class);
        var o = new JSCore.Object (context, c, context);
        var g = context.get_global_object ();
        var s = new JSCore.String.with_utf8_c_string ("Utils");
        g.set_property (context, s, o, JSCore.PropertyAttribute.None, null);
    }
}
