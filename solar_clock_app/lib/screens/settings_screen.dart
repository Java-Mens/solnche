import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/notification_service.dart';

/// Экран настроек приложения (FR-19, FR-20, Раздел 13 ТЗ)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Настройки формата времени
  bool _is24HourFormat = true;
  bool _showMilliseconds = false;
  
  // Настройки уведомлений
  bool _notificationsEnabled = false;
  bool _notifySunrise = true;
  bool _notifySunset = true;
  bool _notifySolarNoon = false;
  
  // Настройки геолокации
  bool _useManualLocation = false;
  double _manualLat = 55.7558; // Москва по умолчанию
  double _manualLon = 37.6173;
  
  // Версия приложения
  final String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _is24HourFormat = prefs.getBool('is24HourFormat') ?? true;
      _showMilliseconds = prefs.getBool('showMilliseconds') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
      _notifySunrise = prefs.getBool('notifySunrise') ?? true;
      _notifySunset = prefs.getBool('notifySunset') ?? true;
      _notifySolarNoon = prefs.getBool('notifySolarNoon') ?? false;
      _useManualLocation = prefs.getBool('useManualLocation') ?? false;
      _manualLat = prefs.getDouble('manualLat') ?? 55.7558;
      _manualLon = prefs.getDouble('manualLon') ?? 37.6173;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is24HourFormat', _is24HourFormat);
    await prefs.setBool('showMilliseconds', _showMilliseconds);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('notifySunrise', _notifySunrise);
    await prefs.setBool('notifySunset', _notifySunset);
    await prefs.setBool('notifySolarNoon', _notifySolarNoon);
    await prefs.setBool('useManualLocation', _useManualLocation);
    await prefs.setDouble('manualLat', _manualLat);
    await prefs.setDouble('manualLon', _manualLon);
    
    // Перенастройка уведомлений при изменении настроек
    if (_notificationsEnabled) {
      await NotificationService.instance.scheduleAllNotifications(
        latitude: _useManualLocation ? _manualLat : null,
        longitude: _useManualLocation ? _manualLon : null,
        notifySunrise: _notifySunrise,
        notifySunset: _notifySunset,
        notifySolarNoon: _notifySolarNoon,
      );
    } else {
      await NotificationService.instance.cancelAllNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Раздел: Формат времени
          _buildSectionTitle('Формат времени'),
          SwitchListTile(
            title: const Text('24-часовой формат'),
            subtitle: const Text('Выключите для 12-часового формата (AM/PM)'),
            value: _is24HourFormat,
            onChanged: (value) {
              setState(() => _is24HourFormat = value);
              _saveSettings();
            },
          ),
          SwitchListTile(
            title: const Text('Показывать миллисекунды'),
            subtitle: const Text('Отображать время с точностью до мс'),
            value: _showMilliseconds,
            onChanged: (value) {
              setState(() => _showMilliseconds = value);
              _saveSettings();
            },
          ),
          
          const Divider(height: 32),
          
          // Раздел: Уведомления
          _buildSectionTitle('Уведомления'),
          SwitchListTile(
            title: const Text('Включить уведомления'),
            subtitle: const Text('Получать уведомления о солнечных событиях'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSettings();
            },
          ),
          if (_notificationsEnabled) ...[
            CheckboxListTile(
              title: const Text('Восход солнца'),
              value: _notifySunrise,
              onChanged: (value) {
                setState(() => _notifySunrise = value ?? true);
                _saveSettings();
              },
            ),
            CheckboxListTile(
              title: const Text('Закат солнца'),
              value: _notifySunset,
              onChanged: (value) {
                setState(() => _notifySunset = value ?? true);
                _saveSettings();
              },
            ),
            CheckboxListTile(
              title: const Text('Солнечный зенит'),
              value: _notifySolarNoon,
              onChanged: (value) {
                setState(() => _notifySolarNoon = value ?? false);
                _saveSettings();
              },
            ),
          ],
          
          const Divider(height: 32),
          
          // Раздел: Геолокация
          _buildSectionTitle('Геолокация'),
          SwitchListTile(
            title: const Text('Ручной ввод координат'),
            subtitle: _useManualLocation
                ? const Text('Широта: $_manualLat°, Долгота: $_manualLon°')
                : const Text('Использовать GPS устройства'),
            value: _useManualLocation,
            onChanged: (value) {
              setState(() => _useManualLocation = value);
              _saveSettings();
            },
          ),
          if (_useManualLocation) ...[
            ListTile(
              title: const Text('Широта'),
              subtitle: Slider(
                value: _manualLat,
                min: -90,
                max: 90,
                divisions: 1800,
                label: _manualLat.toStringAsFixed(4),
                onChanged: (value) {
                  setState(() => _manualLat = value);
                  _saveSettings();
                },
              ),
            ),
            ListTile(
              title: const Text('Долгота'),
              subtitle: Slider(
                value: _manualLon,
                min: -180,
                max: 180,
                divisions: 3600,
                label: _manualLon.toStringAsFixed(4),
                onChanged: (value) {
                  setState(() => _manualLon = value);
                  _saveSettings();
                },
              ),
            ),
          ],
          
          const Divider(height: 32),
          
          // Раздел: О приложении
          _buildSectionTitle('О приложении'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Версия'),
            subtitle: Text(_appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Картографические данные'),
            subtitle: const Text('© OpenStreetMap contributors\nODbL лицензия'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Исходный код'),
            subtitle: const Text('Доступен на GitHub'),
            onTap: () {
              // TODO: Открыть URL в браузере
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('https://github.com/your-repo/solar-clock-app')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Лицензии'),
            subtitle: const Text('MIT License'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Лицензия'),
                  content: SingleChildScrollView(
                    child: Text(
                      'MIT License\n\n'
                      'Copyright (c) 2024 Solar Clock App\n\n'
                      'Permission is hereby granted, free of charge, to any person obtaining a copy\n'
                      'of this software and associated documentation files (the "Software"), to deal\n'
                      'in the Software without restriction, including without limitation the rights\n'
                      'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n'
                      'copies of the Software, and to permit persons to whom the Software is\n'
                      'furnished to do so, subject to the following conditions:\n\n'
                      'The above copyright notice and this permission notice shall be included in all\n'
                      'copies or substantial portions of the Software.\n\n'
                      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n'
                      'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n'
                      'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
