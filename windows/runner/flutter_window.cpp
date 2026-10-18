#include "flutter_window.h"

#include <optional>
#include <mmdeviceapi.h>
#include <shellapi.h>
#include <wrl/client.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

class ComApartment {
 public:
  ComApartment() : status_(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)) {}
  ~ComApartment() {
    if (SUCCEEDED(status_)) CoUninitialize();
  }
  bool available() const {
    return SUCCEEDED(status_) || status_ == RPC_E_CHANGED_MODE;
  }

 private:
  HRESULT status_;
};

std::optional<std::string> DefaultMicrophoneId() {
  ComApartment apartment;
  if (!apartment.available()) return std::nullopt;

  Microsoft::WRL::ComPtr<IMMDeviceEnumerator> enumerator;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                              CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(enumerator.GetAddressOf())))) {
    return std::nullopt;
  }
  Microsoft::WRL::ComPtr<IMMDevice> microphone;
  // Voice calls should use the communications default, not device-list index 0.
  HRESULT status = enumerator->GetDefaultAudioEndpoint(
      eCapture, eCommunications, microphone.GetAddressOf());
  if (FAILED(status)) {
    status = enumerator->GetDefaultAudioEndpoint(
        eCapture, eConsole, microphone.ReleaseAndGetAddressOf());
  }
  if (FAILED(status)) return std::nullopt;

  LPWSTR endpoint_id = nullptr;
  if (FAILED(microphone->GetId(&endpoint_id))) return std::nullopt;
  const std::string id = Utf8FromUtf16(endpoint_id);
  CoTaskMemFree(endpoint_id);
  return id.empty() ? std::nullopt : std::make_optional(id);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  audio_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "reisub_meeting/audio",
      &flutter::StandardMethodCodec::GetInstance());
  audio_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "getDefaultMicrophoneId") {
          result->NotImplemented();
          return;
        }
        const auto id = DefaultMicrophoneId();
        if (!id) {
          result->Error("NotFoundError",
                        "Windows varsayilan mikrofonu bulunamadi. "
                        "Ses ayarlarindan bir giris aygiti secin.");
          return;
        }
        result->Success(flutter::EncodableValue(*id));
      });
  privacy_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "reisub_meeting/privacy",
      &flutter::StandardMethodCodec::GetInstance());
  privacy_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const wchar_t* uri = nullptr;
        if (call.method_name() == "openCameraSettings") {
          uri = L"ms-settings:privacy-webcam";
        } else if (call.method_name() == "openMicrophoneSettings") {
          uri = L"ms-settings:privacy-microphone";
        } else {
          result->NotImplemented();
          return;
        }
        // Open only the requested Settings page; never change consent itself.
        const auto status = reinterpret_cast<INT_PTR>(
            ShellExecuteW(GetHandle(), L"open", uri, nullptr, nullptr, SW_SHOWNORMAL));
        result->Success(flutter::EncodableValue(status > 32));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  audio_channel_ = nullptr;
  privacy_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
