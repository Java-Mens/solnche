# Solar Clock App - Истинное Солнечное Время

Приложение на Flutter, которое определяет местоположение пользователя и отображает истинное солнечное время согласно координатам.

## Функционал

### Основные возможности:
1. **Определение местоположения** - автоматическое получение GPS координат устройства
2. **Расчёт солнечного времени** - вычисление истинного солнечного времени на основе координат
3. **Отображение данных о солнце**:
   - Время восхода
   - Время заката
   - Время солнечного зенита (полудня)

4. **Сравнение точек** - возможность сравнить солнечное время между двумя точками:
   - Текущее местоположение vs заданные координаты
   - Любые две произвольные точки

5. **Android виджет** - виджет для главного экрана с отображением солнечного времени
6. **Уведомления** - опциональные уведомления о солнечном полдне

## Структура проекта

```
lib/
├── main.dart                    # Точка входа приложения
├── models/
│   └── location_point.dart      # Модель точки местоположения
├── providers/
│   └── solar_time_provider.dart # State management (Provider)
├── screens/
│   └── home_screen.dart         # Главный экран
├── services/
│   ├── location_service.dart    # Сервис определения местоположения
│   ├── solar_time_service.dart  # Сервис расчёта солнечного времени
│   ├── notification_service.dart # Сервис уведомлений
│   └── widget_service.dart      # Сервис Android виджета
└── widgets/
    ├── solar_clock_widget.dart        # Виджет солнечных часов
    └── solar_comparison_widget.dart   # Виджет сравнения точек
```

## Зависимости

- `geolocator` - определение местоположения
- `sun_calc` - астрономические расчёты
- `provider` - управление состоянием
- `flutter_local_notifications` - локальные уведомления
- `home_widget` - Android виджеты
- `shared_preferences` - сохранение настроек
- `permission_handler` - управление разрешениями

## Настройка для Android

### AndroidManifest.xml

Добавьте разрешения в `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

### Настройка виджета

В `android/app/src/main/AndroidManifest.xml` добавьте мета-данные:

```xml
<application>
    <meta-data
        android:name="home_widget_config"
        android:resource="@xml/solar_clock_widget_info" />
</application>
```

## Сборка и запуск

```bash
# Установка зависимостей
flutter pub get

# Запуск приложения
flutter run

# Сборка APK
flutter build apk --release

# Сборка для iOS
flutter build ios
```

## Использование

1. При первом запуске предоставьте разрешение на доступ к местоположению
2. Приложение автоматически определит ваши координаты и покажет солнечное время
3. Для добавления точки сравнения нажмите на кнопку "+" или иконку сравнения
4. Введите координаты второй точки для сравнения
5. Для использования виджета добавьте его на главный экран Android

## Технические детали

### Расчёт солнечного времени

Истинное солнечное время рассчитывается по формуле:

```
Солнечное время = Стандартное время + Уравнение времени + 4 × (Долгота - LSTM)
```

где:
- Уравнение времени - поправка на неравномерность движения Земли по орбите
- LSTM (Local Standard Time Meridian) = 15° × часовой пояс

### Уравнение времени

Вычисляется с использованием астрономических формул на основе:
- Средней долготы Солнца
- Средней аномалии Солнца
- Юлианской даты

## Лицензия

MIT License
