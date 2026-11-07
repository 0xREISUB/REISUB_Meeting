#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Registers reisub-meeting:// for the current user, so browsers can offer to
// open invite links in this app. Rewritten on every start because the app is
// shipped as a zip and its folder may have moved since the last run.
void RegisterInviteScheme() {
  wchar_t exe[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return;
  }
  const std::wstring path(exe, length);
  const std::wstring key = L"Software\\Classes\\reisub-meeting";
  auto set = [](const std::wstring& subkey, const wchar_t* name,
                const std::wstring& value) {
    ::RegSetKeyValueW(HKEY_CURRENT_USER, subkey.c_str(), name, REG_SZ,
                      value.c_str(),
                      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
  };
  set(key, nullptr, L"URL:REISUB Meeting");
  set(key, L"URL Protocol", L"");
  set(key + L"\\DefaultIcon", nullptr, L"\"" + path + L"\",0");
  set(key + L"\\shell\\open\\command", nullptr,
      L"\"" + path + L"\" \"%1\"");
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  RegisterInviteScheme();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"REISUB Meeting", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
