#!/bin/zsh

# Build the project

# we delete the build folder because the IDE maybe don't have the permission to delete
# the files in the build folder
echo "\033[1;34mDeleting build folder...\033[0m"
rm -rf build

echo "\033[1;34mDeleting .dart_tool folder...\033[0m"
rm -rf .dart_tool

echo "\033[1;34mRunning flutter clean...\033[0m"
flutter clean

echo "\033[1;34mRunning flutter pub get...\033[0m"
flutter pub get

echo "\033[1;34mRunning flutter pub run build_runner build --delete-conflicting-outputs...\033[0m"
dart run build_runner build --delete-conflicting-outputs

echo "\033[1;34mRunning flutter_launcher_icons...\033[0m"
dart run flutter_launcher_icons:main
rm android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml

echo "\033[1;34mCreating flutter native splash...\033[0m"
dart run flutter_native_splash:create

#echo "\033[1;34mGenerating localization keys...\033[0m"
#dart run easy_localization:generate -S assets/translations -o locale_keys.g.dart -f keys

#echo "\033[1;34mRunning pubspec_extract...\033[0m"
#dart run pubspec_extract

#echo "\033[1;34mBuilding flutter apk...\033[0m"
#flutter build apk