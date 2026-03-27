// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../common/widgets/compact_map_preview.dart';
import '../../orders/presentation/cubit/orders_cubit.dart';
import '../../orders/data/order_api.dart';

class IntercityCity {
  final int id;
  final String name;
  final double price;

  const IntercityCity({required this.id, required this.name, required this.price});

  factory IntercityCity.fromJson(Map<String, dynamic> j) => IntercityCity(
        id: j['id'] as int,
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
      );
}

class IntercityOrderPage extends StatefulWidget {
  final String token;

  const IntercityOrderPage({super.key, required this.token});

  @override
  State<IntercityOrderPage> createState() => _IntercityOrderPageState();
}

class _IntercityOrderPageState extends State<IntercityOrderPage> {
  // Steps: 0=from address, 1=city selection, 2=confirm
  int _step = 0;

  final _fromController = TextEditingController();
  final _descController = TextEditingController();
  LatLng? _fromLocation;

  List<IntercityCity> _cities = [];
  bool _loadingCities = false;
  String? _citiesError;
  IntercityCity? _selectedCity;

  bool _submitting = false;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() { _loadingCities = true; _citiesError = null; });
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/intercity/cities'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _cities = list.map((e) => IntercityCity.fromJson(e as Map<String, dynamic>)).toList();
          _loadingCities = false;
        });
      } else {
        setState(() { _loadingCities = false; _citiesError = 'Шаарларды жүктөөдө ката'; });
      }
    } catch (_) {
      setState(() { _loadingCities = false; _citiesError = 'Интернет байланышы жок'; });
    }
  }

  Future<void> _getMyLocation() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS уруксаты берилген жок'), backgroundColor: Colors.red),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final loc = LatLng(latitude: pos.latitude, longitude: pos.longitude);
      final addr = await RealGeocoder.getAddressFromCoordinates(
        latitude: pos.latitude, longitude: pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _fromLocation = loc;
        _fromController.text = addr;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS катасы: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _submit() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сыпаттама жазыңыз'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await OrderApi().createOrder(
        token: widget.token,
        category: 'intercity',
        description: desc,
        fromAddress: _fromController.text.trim(),
        toAddress: _selectedCity!.name,
        fromLatitude: _fromLocation?.latitude,
        fromLongitude: _fromLocation?.longitude,
        intercityCityId: _selectedCity!.id,
      );
      if (!mounted) return;
      context.read<OrdersCubit>().loadOrders(widget.token);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ ийгиликтүү түзүлдү!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _nextStep() {
    if (_step == 0) {
      if (_fromController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Жөнөтүүнүн адресин киргизиңиз'), backgroundColor: Colors.red),
        );
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_selectedCity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Шаар тандаңыз'), backgroundColor: Colors.red),
        );
        return;
      }
      setState(() => _step = 2);
    }
  }

  void _prevStep() {
    if (_step > 0) { setState(() => _step--); }
    else { Navigator.of(context).pop(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _prevStep,
        ),
        title: Text(
          _step == 0 ? 'Жөнөтүүнүн орду' : _step == 1 ? 'Шаар тандаңыз' : 'Заказды тастыктоо',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _step < 2 ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0: return _buildFromStep();
      case 1: return _buildCityStep();
      case 2: return _buildConfirmStep();
      default: return const SizedBox();
    }
  }

  // ── Step 0: From address ───────────────────────────────────────────────────

  Widget _buildFromStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.directions_car, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Шаарлар аралык жеткирүү',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Кайдан жөнөйсүз?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 4),
          Text('Учурдагы жайгашкан жериңизди же адрести киргизиңиз',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 16),
          AppTextField(
            controller: _fromController,
            hintText: 'Мисал: Баткен, Ленин көч. 15',
            prefixIcon: const Icon(Icons.location_on),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _gettingLocation ? null : _getMyLocation,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _gettingLocation
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18, color: AppColors.primary),
              label: Text(
                _gettingLocation ? 'Аныкталуудa...' : 'Менин учурдагы ордум',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CompactMapPreview(
            initialLocation: _fromLocation,
            label: 'Картадан тандаңыз',
            onLocationChanged: (loc, addr) {
              setState(() {
                _fromLocation = loc;
                _fromController.text = addr;
              });
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Step 1: City selection ─────────────────────────────────────────────────

  Widget _buildCityStep() {
    if (_loadingCities) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_citiesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_citiesError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            AppButton.primary(label: 'Кайра жүктөө', onPressed: _loadCities),
          ],
        ),
      );
    }
    if (_cities.isEmpty) {
      return const Center(
        child: Text('Азырынча шаарлар кошулган жок', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _cities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final city = _cities[i];
        final selected = _selectedCity?.id == city.id;
        return GestureDetector(
          onTap: () => setState(() => _selectedCity = city),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 8)]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.location_city,
                        color: selected ? Colors.white : Colors.grey.shade500, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(city.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: selected ? AppColors.primary : AppColors.textPrimary,
                      )),
                ),
                Text(
                  '${city.price.toStringAsFixed(0)} сом',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Step 2: Confirm ────────────────────────────────────────────────────────

  Widget _buildConfirmStep() {
    final city = _selectedCity!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                _infoRow(Icons.location_on, 'Кайдан', _fromController.text, Colors.green.shade700),
                Divider(color: Colors.green.shade200, height: 16),
                _infoRow(Icons.flag, 'Кайда', city.name, Colors.blue.shade700),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Price
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Жеткирүү баасы',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                ),
                Text(
                  '${city.price.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Сыпаттама', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          AppTextField(
            controller: _descController,
            hintText: 'Мисал: 2 баштык нан, өлчөмү кичине',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Заказ жаратылганда 5 сом сервис акы алынат',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          AppButton.primary(
            label: 'Заказды жарат',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 2),
            SizedBox(
              width: MediaQuery.of(context).size.width - 100,
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2)),
        ],
      ),
      child: AppButton.primary(
        label: _step == 0 ? 'Улантуу →' : 'Шаарды тандоо →',
        onPressed: _nextStep,
      ),
    );
  }
}
