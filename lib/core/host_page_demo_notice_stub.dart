/// No-op on every non-web platform: there is no host HTML page to reveal a
/// banner in. See `host_page_demo_notice.dart`.
void revealHostPageDemoNotice() {}

/// No-op off the web: there is no host page whose theme could drift from the
/// app's. See `host_page_demo_notice.dart`.
void setHostPageTheme({required bool dark}) {}
