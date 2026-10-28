#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$(dirname "$0")" || exit 1

echo "=== SMAPY PRE-CHECK ==="
missing=0

for f in \
  pubspec.yaml \
  lib/main.dart \
  lib/pages/home_page.dart \
  lib/pages/editor_page.dart \
  lib/pages/notebook_page.dart \
  lib/pages/packages_page.dart \
  lib/pages/terminal_page.dart \
  lib/services/linux_launcher.dart \
  lib/services/python_runtime.dart \
  lib/services/runtime_process.dart \
  android_src/MainActivity.kt \
  .github/workflows/android.yml
do
  if [ -s "$f" ]; then
    echo "OK      $f"
  else
    echo "MISSING $f"
    missing=1
  fi
done

echo
if command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK: available"
  flutter --version
else
  echo "Flutter SDK: missing; compile test cannot run locally"
fi

echo
if grep -q 'File.*isAbsolute' lib/services/linux_launcher.dart; then
  echo "Review launcher path checks"
else
  echo "Launcher absolute-path check: no obvious old pattern"
fi

echo
echo "Git changes:"
git status --short

echo
if [ "$missing" -eq 0 ]; then
  echo "Pre-check complete: required files exist."
else
  echo "Pre-check found missing files."
fi

echo "No push or APK build was performed."
