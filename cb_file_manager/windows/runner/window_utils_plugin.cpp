#include "window_utils_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <ole2.h>

#include <memory>
#include <string>
#include <vector>

namespace {

static bool g_is_fullscreen = false;
static RECT g_frame_before_fullscreen = {0, 0, 0, 0};
static LONG_PTR g_style_before_fullscreen = 0;
static bool g_maximized_before_fullscreen = false;

static bool g_ole_initialized = false;
static UINT g_cf_tab_payload = 0;
static UINT g_cf_tab_source_pid = 0;

HWND GetMainWindow(flutter::PluginRegistrarWindows* registrar) {
  if (!registrar) return nullptr;
  auto view = registrar->GetView();
  if (!view) return nullptr;
  return view->GetNativeWindow();
}

HWND GetTopLevelWindow(flutter::PluginRegistrarWindows* registrar) {
  HWND hwnd = GetMainWindow(registrar);
  if (hwnd) {
    HWND root = ::GetAncestor(hwnd, GA_ROOT);
    if (root) return root;
    return hwnd;
  }

  // Fallback for unusual hosting setups.
  return ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", nullptr);
}

RECT GetCurrentMonitorRect(HWND hwnd) {
  RECT monitor_rect = {0, 0, 0, 0};
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info = {0};
  info.cbSize = sizeof(MONITORINFO);
  if (GetMonitorInfo(monitor, &info)) {
    monitor_rect = info.rcMonitor;
  }
  return monitor_rect;
}

void EnterFullscreen(HWND hwnd) {
  if (!hwnd) return;

  if (!g_is_fullscreen) {
    g_maximized_before_fullscreen = ::IsZoomed(hwnd);
    g_style_before_fullscreen = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    ::GetWindowRect(hwnd, &g_frame_before_fullscreen);
  }

  g_is_fullscreen = true;

  const RECT monitor_rect = GetCurrentMonitorRect(hwnd);

  ::SetWindowLongPtr(hwnd, GWL_STYLE,
                     g_style_before_fullscreen & ~WS_OVERLAPPEDWINDOW);

  ::SetWindowPos(hwnd, HWND_TOP, monitor_rect.left, monitor_rect.top,
                 monitor_rect.right - monitor_rect.left,
                 monitor_rect.bottom - monitor_rect.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);

  ::ShowWindow(hwnd, SW_SHOW);
  ::SetForegroundWindow(hwnd);
}

void ExitFullscreen(HWND hwnd) {
  if (!hwnd) return;
  if (!g_is_fullscreen) return;

  g_is_fullscreen = false;

  ::SetWindowLongPtr(hwnd, GWL_STYLE, g_style_before_fullscreen);

  // Refresh the frame.
  ::SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                     SWP_FRAMECHANGED);

  if (g_maximized_before_fullscreen) {
    ::PostMessage(hwnd, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
  } else {
    ::SetWindowPos(hwnd, nullptr, g_frame_before_fullscreen.left,
                   g_frame_before_fullscreen.top,
                   g_frame_before_fullscreen.right -
                       g_frame_before_fullscreen.left,
                   g_frame_before_fullscreen.bottom -
                       g_frame_before_fullscreen.top,
                   SWP_NOACTIVATE | SWP_NOZORDER);
  }

  ::ShowWindow(hwnd, SW_SHOW);
  ::SetForegroundWindow(hwnd);
}

HGLOBAL CopyBytesToHGlobal(const void* data, size_t len) {
  if (!data || len == 0) return nullptr;
  HGLOBAL h = ::GlobalAlloc(GMEM_MOVEABLE, len);
  if (!h) return nullptr;
  void* p = ::GlobalLock(h);
  if (!p) {
    ::GlobalFree(h);
    return nullptr;
  }
  memcpy(p, data, len);
  ::GlobalUnlock(h);
  return h;
}

class TabDataObject : public IDataObject {
 public:
  explicit TabDataObject(std::string payload)
      : payload_(std::move(payload)), source_pid_(::GetCurrentProcessId()) {}

  HRESULT __stdcall QueryInterface(REFIID riid,
                                   void** ppvObject) override {
    if (!ppvObject) return E_POINTER;
    *ppvObject = nullptr;
    if (riid == IID_IUnknown || riid == IID_IDataObject) {
      *ppvObject = static_cast<IDataObject*>(this);
      AddRef();
      return S_OK;
    }
    return E_NOINTERFACE;
  }

  ULONG __stdcall AddRef() override { return ++ref_count_; }

  ULONG __stdcall Release() override {
    const ULONG count = --ref_count_;
    if (count == 0) delete this;
    return count;
  }

  HRESULT __stdcall GetData(FORMATETC* pformatetcIn,
                            STGMEDIUM* pmedium) override {
    if (!pformatetcIn || !pmedium) return E_INVALIDARG;
    if ((pformatetcIn->tymed & TYMED_HGLOBAL) == 0) return DV_E_TYMED;

    if (pformatetcIn->cfFormat == static_cast<CLIPFORMAT>(g_cf_tab_payload)) {
      const size_t len = payload_.size() + 1;
      HGLOBAL h = CopyBytesToHGlobal(payload_.c_str(), len);
      if (!h) return E_OUTOFMEMORY;
      pmedium->tymed = TYMED_HGLOBAL;
      pmedium->hGlobal = h;
      pmedium->pUnkForRelease = nullptr;
      return S_OK;
    }

    if (pformatetcIn->cfFormat ==
        static_cast<CLIPFORMAT>(g_cf_tab_source_pid)) {
      DWORD pid = source_pid_;
      HGLOBAL h = CopyBytesToHGlobal(&pid, sizeof(pid));
      if (!h) return E_OUTOFMEMORY;
      pmedium->tymed = TYMED_HGLOBAL;
      pmedium->hGlobal = h;
      pmedium->pUnkForRelease = nullptr;
      return S_OK;
    }

    return DV_E_FORMATETC;
  }

  HRESULT __stdcall GetDataHere(FORMATETC*, STGMEDIUM*) override {
    return E_NOTIMPL;
  }

  HRESULT __stdcall QueryGetData(FORMATETC* pformatetc) override {
    if (!pformatetc) return E_INVALIDARG;
    if ((pformatetc->tymed & TYMED_HGLOBAL) == 0) return DV_E_TYMED;

    if (pformatetc->cfFormat == static_cast<CLIPFORMAT>(g_cf_tab_payload) ||
        pformatetc->cfFormat == static_cast<CLIPFORMAT>(g_cf_tab_source_pid)) {
      return S_OK;
    }
    return DV_E_FORMATETC;
  }

  HRESULT __stdcall GetCanonicalFormatEtc(FORMATETC*, FORMATETC*) override {
    return E_NOTIMPL;
  }

  HRESULT __stdcall SetData(FORMATETC*, STGMEDIUM*, BOOL) override {
    return E_NOTIMPL;
  }

  HRESULT __stdcall EnumFormatEtc(DWORD, IEnumFORMATETC**) override {
    return E_NOTIMPL;
  }

  HRESULT __stdcall DAdvise(FORMATETC*, DWORD, IAdviseSink*, DWORD*) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

  HRESULT __stdcall DUnadvise(DWORD) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

  HRESULT __stdcall EnumDAdvise(IEnumSTATDATA**) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

 private:
  std::string payload_;
  DWORD source_pid_;
  ULONG ref_count_ = 1;
};

class TabDropSource : public IDropSource {
 public:
  HRESULT __stdcall QueryInterface(REFIID riid,
                                   void** ppvObject) override {
    if (!ppvObject) return E_POINTER;
    *ppvObject = nullptr;
    if (riid == IID_IUnknown || riid == IID_IDropSource) {
      *ppvObject = static_cast<IDropSource*>(this);
      AddRef();
      return S_OK;
    }
    return E_NOINTERFACE;
  }

  ULONG __stdcall AddRef() override { return ++ref_count_; }

  ULONG __stdcall Release() override {
    const ULONG count = --ref_count_;
    if (count == 0) delete this;
    return count;
  }

  HRESULT __stdcall QueryContinueDrag(BOOL fEscapePressed,
                                      DWORD grfKeyState) override {
    if (fEscapePressed) return DRAGDROP_S_CANCEL;
    if ((grfKeyState & MK_LBUTTON) == 0) return DRAGDROP_S_DROP;
    return S_OK;
  }

  HRESULT __stdcall GiveFeedback(DWORD) override {
    return DRAGDROP_S_USEDEFAULTCURSORS;
  }

 private:
  ULONG ref_count_ = 1;
};

class TabDropTarget : public IDropTarget {
 public:
  explicit TabDropTarget(
      flutter::MethodChannel<flutter::EncodableValue>* channel)
      : channel_(channel), pid_(::GetCurrentProcessId()) {}

  HRESULT __stdcall QueryInterface(REFIID riid,
                                   void** ppvObject) override {
    if (!ppvObject) return E_POINTER;
    *ppvObject = nullptr;
    if (riid == IID_IUnknown || riid == IID_IDropTarget) {
      *ppvObject = static_cast<IDropTarget*>(this);
      AddRef();
      return S_OK;
    }
    return E_NOINTERFACE;
  }

  ULONG __stdcall AddRef() override { return ++ref_count_; }

  ULONG __stdcall Release() override {
    const ULONG count = --ref_count_;
    if (count == 0) delete this;
    return count;
  }

  HRESULT __stdcall DragEnter(IDataObject* pDataObj, DWORD, POINTL,
                              DWORD* pdwEffect) override {
    if (!pdwEffect) return E_INVALIDARG;
    allow_drop_ = false;
    if (!CanAccept(pDataObj)) {
      NotifyHover(false);
      *pdwEffect = DROPEFFECT_NONE;
      return S_OK;
    }

    DWORD source_pid = 0;
    if (GetSourcePid(pDataObj, &source_pid) && source_pid == pid_) {
      NotifyHover(false);
      *pdwEffect = DROPEFFECT_NONE;
      return S_OK;
    }

    allow_drop_ = true;
    NotifyHover(true);
    *pdwEffect = DROPEFFECT_MOVE;
    return S_OK;
  }

  HRESULT __stdcall DragOver(DWORD, POINTL, DWORD* pdwEffect) override {
    if (!pdwEffect) return E_INVALIDARG;
    *pdwEffect = allow_drop_ ? DROPEFFECT_MOVE : DROPEFFECT_NONE;
    return S_OK;
  }

  HRESULT __stdcall DragLeave() override {
    NotifyHover(false);
    return S_OK;
  }

  HRESULT __stdcall Drop(IDataObject* pDataObj, DWORD, POINTL,
                         DWORD* pdwEffect) override {
    if (!pdwEffect) return E_INVALIDARG;
    NotifyHover(false);

    DWORD source_pid = 0;
    if (!GetSourcePid(pDataObj, &source_pid)) {
      *pdwEffect = DROPEFFECT_NONE;
      return S_OK;
    }

    // Ignore drops originating from this process to avoid accidental dupes
    // when users click-drag and release within the same window.
    if (source_pid == pid_) {
      *pdwEffect = DROPEFFECT_NONE;
      return S_OK;
    }

    std::string payload;
    if (!GetPayload(pDataObj, &payload) || payload.empty()) {
      *pdwEffect = DROPEFFECT_NONE;
      return S_OK;
    }

    if (channel_) {
      channel_->InvokeMethod(
          "onNativeTabDrop",
          std::make_unique<flutter::EncodableValue>(payload));
    }

    *pdwEffect = DROPEFFECT_MOVE;
    return S_OK;
  }

 private:
  bool CanAccept(IDataObject* data) {
    if (!data) return false;
    FORMATETC fmt = {static_cast<CLIPFORMAT>(g_cf_tab_payload), nullptr,
                     DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
    return data->QueryGetData(&fmt) == S_OK;
  }

  bool GetSourcePid(IDataObject* data, DWORD* out_pid) {
    if (!data || !out_pid) return false;
    FORMATETC fmt = {static_cast<CLIPFORMAT>(g_cf_tab_source_pid), nullptr,
                     DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
    STGMEDIUM medium{};
    if (data->GetData(&fmt, &medium) != S_OK) return false;

    bool ok = false;
    if (medium.tymed == TYMED_HGLOBAL && medium.hGlobal) {
      void* p = ::GlobalLock(medium.hGlobal);
      if (p && ::GlobalSize(medium.hGlobal) >= sizeof(DWORD)) {
        *out_pid = *reinterpret_cast<DWORD*>(p);
        ok = true;
      }
      if (p) ::GlobalUnlock(medium.hGlobal);
    }
    ::ReleaseStgMedium(&medium);
    return ok;
  }

  bool GetPayload(IDataObject* data, std::string* out_payload) {
    if (!data || !out_payload) return false;
    FORMATETC fmt = {static_cast<CLIPFORMAT>(g_cf_tab_payload), nullptr,
                     DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
    STGMEDIUM medium{};
    if (data->GetData(&fmt, &medium) != S_OK) return false;

    bool ok = false;
    if (medium.tymed == TYMED_HGLOBAL && medium.hGlobal) {
      const SIZE_T size = ::GlobalSize(medium.hGlobal);
      void* p = ::GlobalLock(medium.hGlobal);
      if (p && size > 0) {
        const char* c = reinterpret_cast<const char*>(p);
        std::string s(c, c + size);
        while (!s.empty() && s.back() == '\0') s.pop_back();
        *out_payload = std::move(s);
        ok = true;
      }
      if (p) ::GlobalUnlock(medium.hGlobal);
    }
    ::ReleaseStgMedium(&medium);
    return ok;
  }

  void NotifyHover(bool is_hovering) {
    if (hover_notified_ == is_hovering) return;
    hover_notified_ = is_hovering;
    if (!channel_) return;
    channel_->InvokeMethod(
        "onNativeTabDragHover",
        std::make_unique<flutter::EncodableValue>(is_hovering));
  }

  flutter::MethodChannel<flutter::EncodableValue>* channel_;
  DWORD pid_;
  ULONG ref_count_ = 1;
  bool allow_drop_ = false;
  bool hover_notified_ = false;
};

}  // namespace

// static
void WindowUtilsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "cb_file_manager/window_utils",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<WindowUtilsPlugin>(registrar);

  plugin->channel_ = std::move(channel);
  plugin->EnsureDropTargetRegistered();

  plugin->channel_->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

WindowUtilsPlugin::WindowUtilsPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

WindowUtilsPlugin::~WindowUtilsPlugin() {
  if (drop_target_hwnd_) {
    ::RevokeDragDrop(drop_target_hwnd_);
    drop_target_hwnd_ = nullptr;
  }
  if (drop_target_) {
    drop_target_->Release();
    drop_target_ = nullptr;
  }
}

void WindowUtilsPlugin::EnsureDropTargetRegistered() {
  if (drop_target_) return;
  if (!registrar_) return;

  if (!g_ole_initialized) {
    const HRESULT hr = ::OleInitialize(nullptr);
    g_ole_initialized = (hr == S_OK || hr == S_FALSE);
  }

  if (g_cf_tab_payload == 0) {
    g_cf_tab_payload =
        ::RegisterClipboardFormatW(L"CB_FILE_MANAGER_TAB_PAYLOAD_JSON");
  }
  if (g_cf_tab_source_pid == 0) {
    g_cf_tab_source_pid =
        ::RegisterClipboardFormatW(L"CB_FILE_MANAGER_TAB_SOURCE_PID");
  }

  HWND hwnd = GetTopLevelWindow(registrar_);
  if (!hwnd) return;

  drop_target_hwnd_ = hwnd;
  drop_target_ = new TabDropTarget(channel_.get());

  const HRESULT hr = ::RegisterDragDrop(hwnd, drop_target_);
  if (hr == DRAGDROP_E_ALREADYREGISTERED) {
    drop_target_->Release();
    drop_target_ = nullptr;
    drop_target_hwnd_ = nullptr;
    return;
  }
  if (FAILED(hr)) {
    drop_target_->Release();
    drop_target_ = nullptr;
    drop_target_hwnd_ = nullptr;
  }
}

void WindowUtilsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto method = method_call.method_name();

  if (method == "allowForegroundWindow") {
    // Allows this app (or a spawned child) to move itself to the foreground.
    // Use with care: Windows may still apply focus-stealing prevention.
    DWORD target = static_cast<DWORD>(-1);  // ASFW_ANY

    const auto* args =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      auto it_any = args->find(flutter::EncodableValue("any"));
      if (it_any != args->end()) {
        if (const auto* any = std::get_if<bool>(&it_any->second)) {
          if (!*any) {
            target = 0;
          }
        }
      }

      auto it_pid = args->find(flutter::EncodableValue("pid"));
      if (it_pid != args->end()) {
        if (const auto* pid = std::get_if<int>(&it_pid->second)) {
          if (*pid > 0) {
            target = static_cast<DWORD>(*pid);
          }
        }
      }
    } else if (const auto* any_bool =
                   std::get_if<bool>(method_call.arguments())) {
      if (!*any_bool) {
        target = 0;
      }
    }

    const BOOL ok = ::AllowSetForegroundWindow(target);
    result->Success(flutter::EncodableValue(ok != FALSE));
    return;
  }

  if (method == "forceActivateWindow") {
    HWND hwnd = GetTopLevelWindow(registrar_);
    if (!hwnd) {
      result->Error("NO_WINDOW", "Top-level window handle not available.");
      return;
    }

    // Restore if minimized, then try multiple activation paths.
    ::ShowWindow(hwnd, SW_RESTORE);
    ::SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    ::BringWindowToTop(hwnd);
    ::SetActiveWindow(hwnd);

    const BOOL ok = ::SetForegroundWindow(hwnd);
    result->Success(flutter::EncodableValue(ok != FALSE));
    return;
  }

  if (method == "startNativeTabDrag") {
    EnsureDropTargetRegistered();

    const auto* payload =
        std::get_if<std::string>(method_call.arguments());
    if (!payload || payload->empty()) {
      result->Error("INVALID_ARGUMENTS", "Missing payload.");
      return;
    }

    if (!g_ole_initialized || g_cf_tab_payload == 0 || g_cf_tab_source_pid == 0) {
      result->Error("OLE_NOT_INITIALIZED", "OLE drag-drop is not available.");
      return;
    }

    IDataObject* data_object = new TabDataObject(*payload);
    IDropSource* drop_source = new TabDropSource();
    DWORD effect = DROPEFFECT_NONE;
    const HRESULT hr = ::DoDragDrop(data_object, drop_source, DROPEFFECT_MOVE,
                                    &effect);
    drop_source->Release();
    data_object->Release();

    const bool moved = (hr == DRAGDROP_S_DROP) && ((effect & DROPEFFECT_MOVE) != 0);
    result->Success(flutter::EncodableValue(moved ? "moved" : "canceled"));
    return;
  }

  if (method == "setNativeFullScreen") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENTS", "Missing arguments.");
      return;
    }

    const auto it =
        arguments->find(flutter::EncodableValue("isFullScreen"));
    if (it == arguments->end()) {
      result->Error("INVALID_ARGUMENTS", "Missing isFullScreen.");
      return;
    }

    const bool is_fullscreen = std::get<bool>(it->second);
    HWND hwnd = GetTopLevelWindow(registrar_);
    if (!hwnd) {
      result->Error("NO_WINDOW", "Main window handle not available.");
      return;
    }

    if (is_fullscreen) {
      EnterFullscreen(hwnd);
    } else {
      ExitFullscreen(hwnd);
    }

    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (method == "isNativeFullScreen") {
    result->Success(flutter::EncodableValue(g_is_fullscreen));
    return;
  }

  result->NotImplemented();
}
