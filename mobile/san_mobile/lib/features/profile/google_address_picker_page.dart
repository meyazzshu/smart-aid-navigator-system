import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/config.dart';

class PickedGoogleAddress {
  final String addressLine;
  final String city;
  final String state;
  final String postalCode;
  final double? latitude;
  final double? longitude;
  final String formattedAddress;
  final String placeId;

  const PickedGoogleAddress({
    required this.addressLine,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.placeId,
  });
}

class GoogleAddressPickerPage extends StatefulWidget {
  final String initialQuery;

  const GoogleAddressPickerPage({
    super.key,
    this.initialQuery = '',
  });

  @override
  State<GoogleAddressPickerPage> createState() =>
      _GoogleAddressPickerPageState();
}

class _GoogleAddressPickerPageState extends State<GoogleAddressPickerPage> {
  final Dio _dio = Dio();
  final TextEditingController _searchCtrl = TextEditingController();

  Timer? _debounce;
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _predictions = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery;

    if (widget.initialQuery.trim().isNotEmpty) {
      _searchPlaces(widget.initialQuery.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () {
      final query = value.trim();

      if (query.length < 3) {
        setState(() {
          _predictions = [];
          _error = null;
        });
        return;
      }

      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _dio.post(
        'https://places.googleapis.com/v1/places:autocomplete',
        data: {
          'input': query,
          'includedRegionCodes': ['my'],
          'languageCode': 'en',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': AppConfig.mapsApiKey,
            'X-Goog-FieldMask':
                'suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat',
          },
        ),
      );

      final data = (res.data as Map).cast<String, dynamic>();
      final suggestions = (data['suggestions'] as List? ?? []);

      final places = suggestions
          .map((raw) => (raw as Map).cast<String, dynamic>())
          .where((item) => item['placePrediction'] != null)
          .map((item) {
        final prediction =
            (item['placePrediction'] as Map).cast<String, dynamic>();

        final text =
            (prediction['text'] as Map?)?.cast<String, dynamic>()['text']
                    ?.toString() ??
                '';

        final structured =
            (prediction['structuredFormat'] as Map?)?.cast<String, dynamic>();

        final mainText =
            (structured?['mainText'] as Map?)?.cast<String, dynamic>()['text']
                    ?.toString() ??
                text;

        final secondaryText =
            (structured?['secondaryText'] as Map?)
                    ?.cast<String, dynamic>()['text']
                    ?.toString() ??
                '';

        return {
          'place_id': prediction['placeId']?.toString() ?? '',
          'description': text,
          'main_text': mainText,
          'secondary_text': secondaryText,
        };
      }).where((x) => x['place_id']!.isNotEmpty).toList();

      if (!mounted) return;

      setState(() {
        _predictions = places;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Failed to search address. Check Google API key, Places API, and internet connection.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectPlace(String placeId) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _dio.get(
        'https://places.googleapis.com/v1/places/$placeId',
        options: Options(
          headers: {
            'X-Goog-Api-Key': AppConfig.mapsApiKey,
            'X-Goog-FieldMask':
                'id,formattedAddress,addressComponents,location',
          },
        ),
      );

      final data = (res.data as Map).cast<String, dynamic>();

      final components =
          (data['addressComponents'] as List? ?? []).cast<dynamic>();

      String streetNumber = '';
      String route = '';
      String sublocality = '';
      String city = '';
      String state = '';
      String postalCode = '';

      for (final raw in components) {
        final c = (raw as Map).cast<String, dynamic>();

        final longText = c['longText']?.toString() ?? '';
        final shortText = c['shortText']?.toString() ?? '';
        final types = (c['types'] as List? ?? [])
            .map((x) => x.toString())
            .toList();

        if (types.contains('street_number')) {
          streetNumber = longText;
        }

        if (types.contains('route')) {
          route = longText;
        }

        if (types.contains('sublocality') ||
            types.contains('sublocality_level_1')) {
          sublocality = longText;
        }

        if (types.contains('locality')) {
          city = longText;
        }

        if (city.isEmpty &&
            types.contains('administrative_area_level_2')) {
          city = longText;
        }

        if (types.contains('administrative_area_level_1')) {
          state = longText.isNotEmpty ? longText : shortText;
        }

        if (types.contains('postal_code')) {
          postalCode = longText;
        }
      }

      final addressParts = <String>[
        streetNumber,
        route,
        sublocality,
      ].where((x) => x.trim().isNotEmpty).toList();

      final formattedAddress = data['formattedAddress']?.toString() ?? '';

      final location = (data['location'] as Map?)?.cast<String, dynamic>();
      final lat = double.tryParse(location?['latitude']?.toString() ?? '');
      final lng = double.tryParse(location?['longitude']?.toString() ?? '');

      final picked = PickedGoogleAddress(
        addressLine:
            addressParts.isEmpty ? formattedAddress : addressParts.join(', '),
        city: city,
        state: state,
        postalCode: postalCode,
        latitude: lat,
        longitude: lng,
        formattedAddress: formattedAddress,
        placeId: placeId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(picked);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Failed to read selected address. Check Place Details API access.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Address'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search address',
                hintText: 'Example: Bangi, Selangor',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _predictions = [];
                            _error = null;
                          });
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          if (_loading)
            const LinearProgressIndicator(),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          Expanded(
            child: _predictions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Type at least 3 characters to search address using Google Maps.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _predictions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = _predictions[index];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              colorScheme.primary.withOpacity(0.12),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          place['main_text']?.toString() ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          place['secondary_text']?.toString().isNotEmpty == true
                              ? place['secondary_text'].toString()
                              : place['description']?.toString() ?? '',
                        ),
                        onTap: _loading
                            ? null
                            : () => _selectPlace(
                                  place['place_id'].toString(),
                                ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}