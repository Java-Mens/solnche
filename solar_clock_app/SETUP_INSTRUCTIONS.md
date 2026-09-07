# Инструкция по завершению настройки проекта Solar Clock App

## Файлы, которые необходимо создать/настроить вручную

Поскольку Flutter SDK недоступен в текущей среде, некоторые файлы нужно создать вручную после установки Flutter.

### 1. Основные конфигурационные файлы Android

#### android/app/build.gradle
```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

android {
    namespace "com.solarclock.solar_clock_app"
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    defaultConfig {
        applicationId "com.solarclock.solar_clock_app"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}

dependencies {}
```

#### android/build.gradle
```gradle
buildscript {
    ext.kotlin_version = '1.9.0'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(':app')
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
```

#### android/settings.gradle
```gradle
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def flutterSdkPath = properties.getProperty("flutter.sdk")
        assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
        return flutterSdkPath
    }()

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.1.0" apply false
    id "org.jetbrains.kotlin.android" version "1.9.0" apply false
}

include ":app"
```

### 2. AndroidManifest.xml

#### android/app/src/main/AndroidManifest.xml
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Разрешения -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    
    <application
        android:label="@string/app_name"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <!-- Виджет -->
        <receiver
            android:name=".SolarClockWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/solar_clock_widget_info" />
        </receiver>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

### 3. Стили и темы

#### android/app/src/main/res/values/styles.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```

#### android/app/src/main/res/drawable/launch_background.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="?android:colorBackground" />
</layer-list>
```

### 4. MainActivity.kt

#### android/app/src/main/kotlin/com/solarclock/solar_clock_app/MainActivity.kt
```kotlin
package com.solarclock.solar_clock_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
```

### 5. Иконка приложения (заглушка)

Создайте файл `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` с любой PNG иконкой 48x48 пикселей.

Для других плотностей:
- mipmap-mdpi: 36x36
- mipmap-xhdpi: 72x72
- mipmap-xxhdpi: 96x96
- mipmap-xxxhdpi: 192x192

## Установка и запуск

После установки Flutter SDK выполните:

```bash
cd /workspace/solar_clock_app

# Установить зависимости
flutter pub get

# Проверить проект
flutter doctor

# Запустить на эмуляторе/устройстве
flutter run

# Сборка релизного APK
flutter build apk --release
```

## Примечания

1. **Виджет Android**: Для корректной работы виджета необходимо использовать пакет `home_widget`. После первого запуска приложения добавьте виджет на главный экран через стандартный интерфейс Android.

2. **Уведомления**: На Android 13+ требуется явное разрешение пользователя на отправку уведомлений. Приложение запросит это разрешение при первом запуске.

3. **Геолокация**: Для работы в фоне может потребоваться дополнительная настройка разрешений в AndroidManifest.xml.

4. **Тестирование**: Рекомендуется тестировать приложение на реальном устройстве для проверки работы GPS и виджетов.
