import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';
import '../services/solar_time_service.dart';
import '../providers/solar_time_provider.dart';
import '../widgets/solar_clock_widget.dart';
import '../widgets/solar_comparison_widget.dart';

/// Main screen displaying solar time
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadLocation();
  }
  
  Future<void> _loadLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        if (mounted) {
          context.read<SolarTimeProvider>().setCurrentLocation(location);
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Не удалось получить местоположение. Проверьте разрешения.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _showComparisonDialog() {
    showDialog(
      context: context,
      builder: (context) => ComparisonDialog(),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Солнечные Часы'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            onPressed: _showComparisonDialog,
            tooltip: 'Сравнить точки',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Настройки',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocation,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Consumer<SolarTimeProvider>(
        builder: (context, provider, child) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (_errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadLocation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Попробовать снова'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          final currentLocation = provider.currentLocation;
          
          if (currentLocation == null) {
            return const Center(
              child: Text('Местоположение не доступно'),
            );
          }
          
          return RefreshIndicator(
            onRefresh: _loadLocation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  SolarClockWidget(
                    location: currentLocation,
                    label: 'Моё местоположение',
                  ),
                  if (provider.isComparing && provider.comparisonLocation != null)
                    SolarTimeComparisonWidget(
                      location1: currentLocation,
                      location2: provider.comparisonLocation!,
                      label1: 'Моё местоположение',
                      label2: provider.comparisonLocation!.name ?? 'Точка 2',
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showComparisonDialog,
        backgroundColor: Colors.orange[700],
        child: const Icon(Icons.add_location, color: Colors.white),
      ),
    );
  }
}

/// Dialog for setting comparison location
class ComparisonDialog extends StatefulWidget {
  const ComparisonDialog({Key? key}) : super(key: key);
  
  @override
  State<ComparisonDialog> createState() => _ComparisonDialogState();
}

class _ComparisonDialogState extends State<ComparisonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _nameController = TextEditingController();
  
  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  void _saveComparison() {
    if (_formKey.currentState!.validate()) {
      final lat = double.parse(_latitudeController.text);
      final lon = double.parse(_longitudeController.text);
      final name = _nameController.text.isEmpty ? 'Пользовательская точка' : _nameController.text;
      
      final location = LocationPoint(
        latitude: lat,
        longitude: lon,
        name: name,
      );
      
      context.read<SolarTimeProvider>().setComparisonLocation(location);
      context.read<SolarTimeProvider>().saveComparisonLocation();
      
      Navigator.of(context).pop();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final existingLocation = context.read<SolarTimeProvider>().comparisonLocation;
    
    if (existingLocation != null) {
      _latitudeController.text = existingLocation.latitude.toString();
      _longitudeController.text = existingLocation.longitude.toString();
      _nameController.text = existingLocation.name ?? '';
    }
    
    return AlertDialog(
      title: const Text('Добавить точку для сравнения'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _latitudeController,
                decoration: const InputDecoration(
                  labelText: 'Широта',
                  hintText: 'Например: 55.7558',
                  prefixIcon: Icon(Icons.location_on),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите широту';
                  }
                  try {
                    final lat = double.parse(value);
                    if (lat < -90 || lat > 90) {
                      return 'Широта должна быть от -90 до 90';
                    }
                  } catch (e) {
                    return 'Неверный формат';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _longitudeController,
                decoration: const InputDecoration(
                  labelText: 'Долгота',
                  hintText: 'Например: 37.6173',
                  prefixIcon: Icon(Icons.location_on),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите долготу';
                  }
                  try {
                    final lon = double.parse(value);
                    if (lon < -180 || lon > 180) {
                      return 'Долгота должна быть от -180 до 180';
                    }
                  } catch (e) {
                    return 'Неверный формат';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название (необязательно)',
                  hintText: 'Например: Москва',
                  prefixIcon: Icon(Icons.label),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (existingLocation != null)
          TextButton(
            onPressed: () {
              context.read<SolarTimeProvider>().clearComparisonLocation();
              context.read<SolarTimeProvider>().saveComparisonLocation();
              Navigator.of(context).pop();
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _saveComparison,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
