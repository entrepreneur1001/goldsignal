import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/firebase/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _countryKeys = [
    'sa', 'ae', 'eg', 'kw', 'bh', 'om', 'qa', 'jo', 'lb', 'iq', 'pk', 'in',
    'us', 'gb', 'other',
  ];

  static const _legacyCountryToKey = {
    'Saudi Arabia': 'sa',
    'United Arab Emirates': 'ae',
    'Egypt': 'eg',
    'Kuwait': 'kw',
    'Bahrain': 'bh',
    'Oman': 'om',
    'Qatar': 'qa',
    'Jordan': 'jo',
    'Lebanon': 'lb',
    'Iraq': 'iq',
    'Pakistan': 'pk',
    'India': 'in',
    'United States': 'us',
    'United Kingdom': 'gb',
    'Other': 'other',
  };

  final AuthService _authService = AuthService();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  String? _countryKey;
  DateTime? _dob;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String? _normalizeCountry(String? stored) {
    if (stored == null) return null;
    if (_countryKeys.contains(stored)) return stored;
    return _legacyCountryToKey[stored];
  }

  Future<void> _load() async {
    final data = await _authService.loadProfile();
    if (!mounted) return;
    final name = (data?['displayName'] as String?) ??
        _authService.currentUser?.displayName ??
        '';
    _nameController.text = name;
    _cityController.text = (data?['city'] as String?) ?? '';
    final country = data?['country'] as String?;
    final dobRaw = data?['dob'] as String?;
    setState(() {
      _countryKey = _normalizeCountry(country);
      _dob = dobRaw != null ? DateTime.tryParse(dobRaw) : null;
      _loading = false;
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('profile.enter_name'))),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _authService.updateProfile(
        name: _nameController.text.trim(),
        country: _countryKey,
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        dob: _dob,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('success.profile_updated'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.edit_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: context.tr('profile.full_name'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _countryKey,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('profile.country'),
                    prefixIcon: const Icon(Icons.public),
                    border: const OutlineInputBorder(),
                  ),
                  items: _countryKeys
                      .map((key) => DropdownMenuItem(
                            value: key,
                            child: Text(context.tr('countries.$key')),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _countryKey = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: context.tr('profile.city'),
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDob,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.tr('profile.dob'),
                      prefixIcon: const Icon(Icons.cake_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      _dob != null
                          ? MaterialLocalizations.of(context)
                              .formatMediumDate(_dob!)
                          : context.tr('profile.dob_hint'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('common.save')),
                ),
              ],
            ),
    );
  }
}
