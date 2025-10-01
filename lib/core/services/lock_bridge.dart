class LockBridge {
  static bool suppressNextLock = false;

  static void suppressOnce() {
    suppressNextLock = true;
  }
}

