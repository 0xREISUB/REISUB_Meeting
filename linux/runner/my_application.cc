#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

// The command line flag of a start at login: no window until asked for.
#define START_HIDDEN_FLAG "--hidden"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // The app's one window; it may be hidden, with the app running on in the
  // background.
  GtkWindow* window;
  gboolean start_hidden;
  // Hands invite links from later starts to the running app.
  FlMethodChannel* links_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  if (self->start_hidden) return;
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window != nullptr) {
    // Started again: the one window comes back instead of a second app.
    gtk_widget_show(GTK_WIDGET(self->window));
    gtk_window_present(self->window);
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  g_object_add_weak_pointer(G_OBJECT(window),
                            reinterpret_cast<gpointer*>(&self->window));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "REISUB Meeting");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "REISUB Meeting");
  }

  // Rounded corners: with a compositor the window can be see-through, so
  // only the app, which clips itself to rounded corners, is drawn. The
  // window's own background goes, and its shadow follows the same corners.
  //
  // Not on X11: there GTK blends every frame of a see-through Flutter view
  // through the CPU, and large windows stutter. Wayland has no such cost.
  // REISUB_OPAQUE_WINDOW=1 keeps the window opaque anywhere.
  GdkScreen* window_screen = gtk_window_get_screen(window);
  GdkVisual* rgba_visual = gdk_screen_get_rgba_visual(window_screen);
  const gchar* opaque = g_getenv("REISUB_OPAQUE_WINDOW");
  gboolean see_through =
      (opaque == nullptr || g_strcmp0(opaque, "") == 0 ||
       g_strcmp0(opaque, "0") == 0) &&
      rgba_visual != nullptr && gdk_screen_is_composited(window_screen);
#ifdef GDK_WINDOWING_X11
  if (GDK_IS_X11_SCREEN(window_screen)) {
    see_through = FALSE;
  }
#endif
  // Tells the app whether to round its corners.
  g_setenv("REISUB_ROUNDED_WINDOW", see_through ? "1" : "0", TRUE);
  if (see_through) {
    gtk_widget_set_visual(GTK_WIDGET(window), rgba_visual);
    gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
    g_autoptr(GtkCssProvider) css = gtk_css_provider_new();
    gtk_css_provider_load_from_data(
        css,
        "window, window.background { background-color: transparent; }"
        "decoration { border-radius: 12px; }",
        -1, nullptr);
    gtk_style_context_add_provider_for_screen(
        window_screen, GTK_STYLE_PROVIDER(css),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

  gtk_window_set_default_size(window, 1280, 720);
  g_autoptr(GdkPixbuf) icon = gdk_pixbuf_new_from_resource(
      "/xyz/reisub/meeting/logo.png", nullptr);
  if (icon != nullptr) {
    gtk_window_set_icon(window, icon);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, see_through ? "#00000000" : "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->links_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "reisub_meeting/links", FL_METHOD_CODEC(codec));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean has_flag(gchar** arguments, const gchar* flag) {
  for (gchar** arg = arguments; arg != nullptr && *arg != nullptr; arg++) {
    if (g_strcmp0(*arg, flag) == 0) return TRUE;
  }
  return FALSE;
}

// Implements GApplication::command_line. The app runs once: a later start
// (the dock, the menu, an invite link) reaches the running app here, which
// shows its window and opens the link.
static int my_application_command_line(GApplication* application,
                                       GApplicationCommandLine* command_line) {
  MyApplication* self = MY_APPLICATION(application);
  g_auto(GStrv) arguments =
      g_application_command_line_get_arguments(command_line, nullptr);
  // The first argument is the binary's name.
  gchar** rest = arguments[0] != nullptr ? arguments + 1 : arguments;
  if (self->window == nullptr) {
    self->dart_entrypoint_arguments = g_strdupv(rest);
    self->start_hidden = has_flag(rest, START_HIDDEN_FLAG);
    g_application_activate(application);
    return 0;
  }
  if (self->links_channel != nullptr) {
    for (gchar** arg = rest; *arg != nullptr; arg++) {
      if (g_str_has_prefix(*arg, "-")) continue;
      fl_method_channel_invoke_method(self->links_channel, "onLink",
                                      fl_value_new_string(*arg), nullptr,
                                      nullptr, nullptr);
    }
  }
  // A second start at login leaves the window as it is.
  if (!has_flag(rest, START_HIDDEN_FLAG)) {
    self->start_hidden = FALSE;
    g_application_activate(application);
  }
  return 0;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->links_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_HANDLES_COMMAND_LINE,
                                     nullptr));
}
