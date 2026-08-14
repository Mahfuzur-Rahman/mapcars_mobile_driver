import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/mc.dart';
import '../services/vehicle_service.dart';

/// Add/edit the driver's vehicle. Prefilled from [vehicle] when editing an
/// existing one. Pops with the saved [Vehicle] on success.
class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  late final _makeCtrl = TextEditingController(text: widget.vehicle?.make);
  late final _modelCtrl = TextEditingController(text: widget.vehicle?.model);
  late final _yearCtrl =
      TextEditingController(text: widget.vehicle?.year.toString());
  late final _colourCtrl = TextEditingController(text: widget.vehicle?.colour);
  late final _regCtrl =
      TextEditingController(text: widget.vehicle?.registrationNumber);
  late final _phvPlateCtrl =
      TextEditingController(text: widget.vehicle?.phvLicencePlateNumber);
  late final _phvAuthorityCtrl =
      TextEditingController(text: widget.vehicle?.phvLicensingAuthority);

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _colourCtrl.dispose();
    _regCtrl.dispose();
    _phvPlateCtrl.dispose();
    _phvAuthorityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final make = _makeCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final colour = _colourCtrl.text.trim();
    final registration = _regCtrl.text.trim();
    final year = int.tryParse(_yearCtrl.text.trim());

    if (make.isEmpty || model.isEmpty || colour.isEmpty || registration.isEmpty || year == null) {
      setState(() => _error = 'Please fill in every field.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final vehicle = await ref.read(vehicleServiceProvider).upsert(
            make: make,
            model: model,
            year: year,
            colour: colour,
            registrationNumber: registration,
            phvLicencePlateNumber: _phvPlateCtrl.text.trim(),
            phvLicensingAuthority: _phvAuthorityCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(vehicle);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : "Couldn't save your vehicle. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Ico('chevL', size: 22, color: Brand.ink),
                  ),
                  const SizedBox(width: 12),
                  McTitle(widget.vehicle == null ? 'Add your vehicle' : 'Edit vehicle', size: 22),
                  const Spacer(),
                  const McMenuButton(),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Make', required: true),
                      McField(icon: 'car', controller: _makeCtrl, editable: true),
                      const SizedBox(height: 12),
                      _label('Model', required: true),
                      McField(icon: 'car', controller: _modelCtrl, editable: true),
                      const SizedBox(height: 12),
                      _label('Year', required: true),
                      McField(
                        icon: 'cal',
                        controller: _yearCtrl,
                        editable: true,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _label('Colour', required: true),
                      McField(icon: 'car', controller: _colourCtrl, editable: true),
                      const SizedBox(height: 12),
                      _label('Registration number', required: true),
                      McField(icon: 'doc', controller: _regCtrl, editable: true),
                      const SizedBox(height: 12),
                      _label('PHV vehicle licence plate (optional)'),
                      McField(icon: 'doc', controller: _phvPlateCtrl, editable: true),
                      const SizedBox(height: 12),
                      _label('PHV licensing authority (optional)'),
                      McField(icon: 'doc', controller: _phvAuthorityCtrl, editable: true),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: tw(FontWeight.w600, 13, Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      McButton(
                        _saving ? 'Saving…' : 'Save vehicle',
                        icon: _saving ? null : 'chevR',
                        onTap: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: RichText(
          text: TextSpan(
            style: tw(FontWeight.w800, 12, Brand.sub),
            children: [
              TextSpan(text: text),
              if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
}
