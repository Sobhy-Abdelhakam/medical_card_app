import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../di/injection_container.dart';
import '../../../providers/domain/entities/provider_entity.dart';
import '../../../providers/presentation/cubit/map_providers/map_providers_cubit.dart';
import '../services/location_service.dart';

// ============================================================================
// CONSTANTS & CONFIGURATION
// ============================================================================

const double _defaultMapZoom = 15.0;
const double _defaultLatitude = 30.0444;
const double _defaultLongitude = 31.2357;

const Duration _animationDuration = Duration(milliseconds: 300);
const Duration _debounceDuration = Duration(milliseconds: 400);

// Use slightly larger icons for better visibility on high-DPI screens
const double _iconSizeNormal = 45.0;
const double _iconSizeSelected = 50.0;
const double _iconBorderWidth = 1.0;

Map<String, Map<String, dynamic>> _typeIconMap = {
  'صيدلية': {'icon': Icons.local_pharmacy, 'color': Colors.green},
  'مستشفى': {'icon': Icons.local_hospital, 'color': Colors.red},
  'معمل تحاليل': {'icon': Icons.science, 'color': Colors.blue},
  'مركز أشعة': {'icon': Icons.medical_services, 'color': Colors.deepPurple},
  'علاج طبيعي': {'icon': Icons.accessibility_new, 'color': Colors.orange},
  'مركز متخصص': {'icon': Icons.star, 'color': Colors.teal},
  'عيادة': {'icon': Icons.local_hospital, 'color': Colors.pink},
  'بصريات': {'icon': Icons.visibility, 'color': Colors.brown},
};

// ============================================================================
// MAIN WIDGET
// ============================================================================

class MapData extends StatefulWidget {
  const MapData({super.key});

  @override
  State<MapData> createState() => _MapDataState();
}

class _MapDataState extends State<MapData> with WidgetsBindingObserver {
  // Logic & Services
  late final MapProvidersCubit _cubit;
  late final _MapIconCache _iconCache;
  late final ValueNotifier<Set<Marker>> _markersNotifier;

  // Controllers
  late GoogleMapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  Timer? _cameraIdleTimer;

  // Local State
  LatLng? _currentLocation;
  bool _areIconsReady = false;
  bool _isFilterExpanded = false;
  bool _showLegend = false;
  bool _isLocationLoading = false;
  bool _locationPermissionGranted = false;

  // Viewport & Data
  LatLngBounds? _visibleBounds;
  List<ProviderEntity>? _filteredProviders;
  List<ProviderEntity>? _visibleProviders;
  ProviderEntity? _selectedProvider;
  final Map<String, Marker> _markerCache = {};

  // Marker Rendering
  Timer? _batchTimer;
  int _batchIndex = 0;
  static const int _batchSize = 30;
  static const Duration _cameraIdleDebounce = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = sl<MapProvidersCubit>();
    _iconCache = _MapIconCache();
    _markersNotifier = ValueNotifier<Set<Marker>>(const {});

    _initializeApp();

    // Fetch location AFTER first frame is rendered (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLocationPostFrame();
    });
  }

  Future<void> _initializeApp() async {
    // Request permission in background without blocking UI
    final permissionStatus = await LocationService.requestLocationPermission();
    _locationPermissionGranted =
        permissionStatus == LocationPermissionStatus.granted;
    _startParallelInitialization();
  }

  void _startParallelInitialization() {
    // Generate icons asynchronously in background
    _iconCache.generateTypeIcons(_typeIconMap).then((_) {
      if (mounted) setState(() => _areIconsReady = true);
    });

    // Load map providers in background
    _cubit.loadMapProviders();
  }

  /// Fetch location after UI is fully rendered (non-blocking)
  Future<void> _fetchLocationPostFrame() async {
    if (!mounted) return;
    if (!_locationPermissionGranted) return;

    setState(() => _isLocationLoading = true);

    try {
      // This won't block UI - location fetch happens in background
      final location = await LocationService.getCurrentLocation();

      if (!mounted) return;

      setState(() => _isLocationLoading = false);

      if (location != null) {
        setState(() => _currentLocation = location);
        // Safe camera animation (only if controller is ready)
        if (_mapController != null) {
          _animateCameraToLocation(location);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  /// Safely animate camera to location
  void _animateCameraToLocation(LatLng location) {
    try {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15.0),
      );
    } catch (e) {
      // Silently handle animation errors (controller might be disposed)
      debugPrint('Camera animation error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _batchTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _cameraIdleTimer?.cancel();
    _markersNotifier.dispose();
    _cubit.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation({bool animate = false}) async {
    if (!mounted || !_locationPermissionGranted) return;
    setState(() => _isLocationLoading = true);

    try {
      final loc = await LocationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _isLocationLoading = false;
        if (loc != null) _currentLocation = loc;
      });

    if (loc != null && animate) {
      _moveCameraToLocation(loc);
    }
    } catch (_) {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }
  Future<void> _moveCameraToLocation(LatLng location) async {
  try {
    await _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 16,
        ),
      ),
    );
  } catch (_) {
    // ignore (controller not ready or disposed)
  }
}

  // --- Search Logic ---

  void _onSearchChanged(String query) {
    if (_searchDebounceTimer?.isActive ?? false) _searchDebounceTimer!.cancel();
    _searchDebounceTimer = Timer(_debounceDuration, () {
      if (query.isEmpty) {
        _cubit.clearFilters();
      } else {
        _cubit.searchMapProviders(query);
      }
    });
  }

  // --- Viewport & Camera Logic ---

  void _onCameraMove(CameraPosition position) {
    _visibleBounds = _calculateVisibleBounds(position);
  }

  void _onCameraIdle() {
    _cameraIdleTimer?.cancel();
    _cameraIdleTimer = Timer(_cameraIdleDebounce, () {
      if (!mounted) return;
      _updateVisibleMarkers();
    });
  }

  LatLngBounds _calculateVisibleBounds(CameraPosition position) {
    const zoomPadding = 0.15;
    final distance = 40000 / pow(2, position.zoom);
    final latOffset = distance / 111.0;
    final lngOffset =
        distance / (111.0 * cos(position.target.latitude * pi / 180));

    return LatLngBounds(
      southwest: LatLng(
        position.target.latitude - latOffset * (1 + zoomPadding),
        position.target.longitude - lngOffset * (1 + zoomPadding),
      ),
      northeast: LatLng(
        position.target.latitude + latOffset * (1 + zoomPadding),
        position.target.longitude + lngOffset * (1 + zoomPadding),
      ),
    );
  }

  bool _isProviderVisible(ProviderEntity provider) {
    if (_visibleBounds == null) return true;
    final markerLatLng =
        LatLng(provider.latitude ?? 0, provider.longitude ?? 0);
    return _visibleBounds!.contains(markerLatLng);
  }

  void _updateVisibleMarkers() {
    if (_filteredProviders == null || !_areIconsReady) return;
    _visibleProviders = _filteredProviders!.where(_isProviderVisible).toList();
    _scheduleMarkerBatch(_visibleProviders ?? [], _selectedProvider);
  }

  // --- Marker Rendering ---

  void _scheduleMarkerBatch(
      List<ProviderEntity> providers, ProviderEntity? selected) {
    _batchTimer?.cancel();

    if (providers.isEmpty) {
      _markersNotifier.value = const {};
      return;
    }

    final Set<Marker> newMarkers = {};
    _batchIndex = 0;

    _batchTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final int start = _batchIndex;
      final int end = (start + _batchSize < providers.length)
          ? start + _batchSize
          : providers.length;

      if (start >= providers.length) {
        timer.cancel();
        _markersNotifier.value = newMarkers;
        return;
      }

      for (int i = start; i < end; i++) {
        final provider = providers[i];
        final isSelected = selected?.id == provider.id;
        newMarkers.add(_buildMarker(provider, isSelected));
      }

      _batchIndex = end;
      _markersNotifier.value = Set.from(newMarkers);
    });
  }

  Marker _buildMarker(ProviderEntity provider, bool isSelected) {
    final cacheKey = '${provider.id}_${isSelected ? 'sel' : 'def'}';
    return _markerCache.putIfAbsent(cacheKey, () {
      final type = provider.type;
      final icon = isSelected
          ? (_iconCache.getSelectedIcon(type) ??
              _iconCache.getDefaultSelectedIcon())
          : (_iconCache.getIcon(type) ?? _iconCache.getDefaultIcon());

      return Marker(
        markerId: MarkerId(provider.id.toString()),
        position: LatLng(provider.latitude ?? 0, provider.longitude ?? 0),
        icon: icon ?? BitmapDescriptor.defaultMarker,
        zIndexInt: isSelected ? 10 : 1,
        anchor: const Offset(0.5, 0.5),
        onTap: () => _onMarkerTap(provider),
      );
    });
  }

  void _onMarkerTap(ProviderEntity provider) {
    _cubit.selectProvider(provider);
    _showProviderDetails(provider);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Map Layer
            _buildMapLayer(),

            // Search & Filters
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFloatingSearchBar(),
                      BlocBuilder<MapProvidersCubit, MapProvidersState>(
                        builder: (context, state) {
                          if (state is MapProvidersLoading) {
                            return Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: LinearProgressIndicator(
                                minHeight: 2.h,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation(
                                    Theme.of(context).primaryColor),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      AnimatedSize(
                        duration: _animationDuration,
                        curve: Curves.easeOutCubic,
                        child: _isFilterExpanded
                            ? Padding(
                                padding: EdgeInsets.only(top: 12.h),
                                child: _FilterChipsList(cubit: _cubit),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating Controls
            Positioned(
              bottom: 100.h,
              right: 16.w,
              child: _buildFloatingControls(),
            ),

            // Legend
            if (_showLegend)
              Positioned(
                bottom: 110.h,
                left: 16.w,
                child: _LegendWidget(
                    onClose: () => setState(() => _showLegend = false)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLayer() {
    return BlocListener<MapProvidersCubit, MapProvidersState>(
      listener: (context, state) {
        if (state is MapProvidersError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
        if (state is MapProvidersLoaded) {
          _filteredProviders = state.filteredProviders;
          _selectedProvider = state.selectedProvider;
          if (_visibleBounds != null && _areIconsReady) {
            _updateVisibleMarkers();
          }
        }
      },
      child: _ProviderMapView(
        markersNotifier: _markersNotifier,
        myLocationEnabled: _locationPermissionGranted,
        currentLocation: _currentLocation,
        onMapCreated: _onMapCreated,
        onCameraMove: _onCameraMove,
        onCameraIdle: _onCameraIdle,
        onMapTap: () {
          FocusScope.of(context).unfocus();
          _cubit.selectProvider(null);
        },
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _updateVisibleMarkers();
    });
  }

  Widget _buildFloatingSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            SizedBox(width: 16.w),
            Icon(Icons.search, color: Colors.grey[600], size: 22.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: context.tr('search_hint'),
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 13.sp),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                ),
              ),
            ),
            Container(
              height: 24.h,
              width: 1,
              color: Colors.grey[300],
              margin: EdgeInsets.symmetric(horizontal: 4.w),
            ),
            IconButton(
              icon: Icon(
                _isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                color: _isFilterExpanded
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
                size: 22.sp,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _isFilterExpanded = !_isFilterExpanded);
              },
            ),
            SizedBox(width: 4.w),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildFab(
          heroTag: 'legend_fab',
          icon: _showLegend ? Icons.close : Icons.info_outline,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showLegend = !_showLegend);
          },
          backgroundColor: Colors.white,
          iconColor: Theme.of(context).primaryColor,
        ),
        SizedBox(height: 12.h),
        _buildFab(
          heroTag: 'location_fab',
          icon: _isLocationLoading ? Icons.gps_not_fixed : Icons.my_location,
          onTap: () => _getCurrentLocation(animate: true),
          isLoading: _isLocationLoading,
        ),
      ],
    );
  }

  Widget _buildFab({
    required String heroTag,
    required IconData icon,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? iconColor,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: 50.w,
      height: 50.w,
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onTap,
        backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
        elevation: 6,
        highlightElevation: 10,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: isLoading
            ? Padding(
                padding: EdgeInsets.all(14.w),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(iconColor ?? Colors.white),
                ),
              )
            : Icon(icon, color: iconColor ?? Colors.white, size: 24.sp),
      ),
    );
  }

  void _showProviderDetails(ProviderEntity provider) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProviderDetailsSheet(provider: provider),
    ).whenComplete(() {
      _cubit.selectProvider(null);
    });
  }
}

// ============================================================================
// SUB-WIDGETS
// ============================================================================

class _ProviderMapView extends StatefulWidget {
  final ValueNotifier<Set<Marker>> markersNotifier;
  final bool myLocationEnabled;
  final LatLng? currentLocation;
  final void Function(GoogleMapController) onMapCreated;
  final void Function(CameraPosition) onCameraMove;
  final VoidCallback onCameraIdle;
  final VoidCallback onMapTap;

  const _ProviderMapView({
    required this.markersNotifier,
    required this.myLocationEnabled,
    required this.currentLocation,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onMapTap,
  });

  @override
  State<_ProviderMapView> createState() => _ProviderMapViewState();
}

class _ProviderMapViewState extends State<_ProviderMapView> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(_defaultLatitude, _defaultLongitude),
    zoom: _defaultMapZoom,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<Marker>>(
      valueListenable: widget.markersNotifier,
      builder: (context, markers, _) {
        return GoogleMap(
          initialCameraPosition: _initialCameraPosition,
          markers: markers,
          onMapCreated: _handleMapCreated,
          onCameraMove: widget.onCameraMove,
          onCameraIdle: widget.onCameraIdle,
          myLocationEnabled: widget.myLocationEnabled,
          myLocationButtonEnabled: false,
          trafficEnabled: false,
          buildingsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: false,
          onTap: (_) => widget.onMapTap(),
        );
      },
    );
  }

  void _handleMapCreated(GoogleMapController controller) {
    widget.onMapCreated(controller);
  }
}

class _FilterChipsList extends StatelessWidget {
  final MapProvidersCubit cubit;
  const _FilterChipsList({required this.cubit});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapProvidersCubit, MapProvidersState>(
      buildWhen: (previous, current) {
        if (previous is MapProvidersLoaded && current is MapProvidersLoaded) {
          return previous.selectedTypes != current.selectedTypes;
        }
        return true;
      },
      builder: (context, state) {
        if (state is! MapProvidersLoaded) return const SizedBox();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip(
                context,
                label: context.tr('all_types'),
                isSelected: state.selectedTypes.isEmpty,
                onTap: () => cubit.clearFilters(),
              ),
              ..._typeIconMap.keys.map((type) {
                final isSelected = state.selectedTypes.contains(type);
                return _buildFilterChip(
                  context,
                  label: type,
                  isSelected: isSelected,
                  onTap: () => cubit.toggleType(type),
                  iconData: _typeIconMap[type]?['icon'],
                  color: _typeIconMap[type]?['color'],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? iconData,
    Color? color,
  }) {
    final themeColor = color ?? Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: isSelected ? null : Border.all(color: Colors.grey[200]!),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconData != null) ...[
                    Icon(
                      iconData,
                      size: 16.sp,
                      color: isSelected ? Colors.white : themeColor,
                    ),
                    SizedBox(width: 6.w),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendWidget extends StatelessWidget {
  final VoidCallback onClose;
  const _LegendWidget({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      width: 220.w,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('legend_title'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                InkWell(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 200.h),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: _typeIconMap.entries
                      .map((e) => Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: Row(
                              children: [
                                Icon(e.value['icon'],
                                    color: e.value['color'], size: 18),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[800]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderDetailsSheet extends StatelessWidget {
  final ProviderEntity provider;
  const _ProviderDetailsSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 30)],
      ),
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 24.h),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: (_typeIconMap[provider.type]?['color'] ??
                          Theme.of(context).primaryColor)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  _typeIconMap[provider.type]?['icon'] ?? Icons.local_hospital,
                  color: _typeIconMap[provider.type]?['color'] ??
                      Theme.of(context).primaryColor,
                  size: 32.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.name,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        provider.type,
                        style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),
          const Divider(color: Color(0xFFE0E0E0), height: 1),
          SizedBox(height: 20.h),

          // Details
          _DetailRow(icon: Icons.place_outlined, text: provider.address),
          if (provider.phone.isNotEmpty)
            _DetailRow(
                icon: Icons.phone_outlined,
                text: provider.phone,
                isPhone: true),
          if (provider.discountPct.isNotEmpty)
            _DetailRow(
              icon: Icons.local_offer_outlined,
              text: '${context.tr('discount')}: ${provider.discountPct}%',
              color: Colors.green[700],
              hasBg: true,
            ),

          SizedBox(height: 24.h),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _MainActionButton(
                  icon: Icons.call,
                  label: context.tr('call_button'),
                  color: Colors.green,
                  onTap: () => _launchUrl('tel:${provider.phone}'),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _MainActionButton(
                  icon: Icons.map,
                  label: context.tr('location_button'),
                  color: Theme.of(context).primaryColor,
                  onTap: () => _launchUrl(provider.mapUrl),
                  isOutlined: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isPhone;
  final Color? color;
  final bool hasBg;

  const _DetailRow({
    required this.icon,
    required this.text,
    this.isPhone = false,
    this.color,
    this.hasBg = false,
  });

  @override
  Widget build(BuildContext context) {
    if (hasBg) {
      return Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: (color ?? Colors.blue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: color),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                    fontSize: 14.sp, color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.sp, color: Colors.grey[400]),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[800],
                fontWeight: FontWeight.w400,
                height: 1.3,
                fontFamily: isPhone ? 'Roboto' : null,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isOutlined;

  const _MainActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isOutlined ? Colors.transparent : color,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            border: isOutlined
                ? Border.all(color: color.withOpacity(0.4), width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isOutlined ? color : Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  color: isOutlined ? color : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HELPERS
// ============================================================================

class _MapIconCache {
  static final Map<String, BitmapDescriptor> _staticIconCache = {};
  static final Map<String, BitmapDescriptor> _staticSelectedIconCache = {};
  static bool _isGenerated = false;

  Future<void> generateTypeIcons(
      Map<String, Map<String, dynamic>> typeIconMap) async {
    if (_isGenerated) return;

    try {
      final futures = <Future>[];

      futures.add(_BitmapGenerator.create(
              Icons.location_on, Colors.blue, _iconSizeNormal)
          .then((icon) => _staticIconCache['default'] = icon));
      futures.add(_BitmapGenerator.create(
              Icons.location_on, Colors.blue, _iconSizeSelected,
              isSelected: true)
          .then((icon) => _staticSelectedIconCache['default'] = icon));

      for (var entry in typeIconMap.entries) {
        final type = entry.key;
        final icon = entry.value['icon'] as IconData;
        final color = entry.value['color'] as Color;

        futures.add(_BitmapGenerator.create(icon, color, _iconSizeNormal)
            .then((desc) => _staticIconCache[type] = desc));
        futures.add(_BitmapGenerator.create(icon, color, _iconSizeSelected,
                isSelected: true)
            .then((desc) => _staticSelectedIconCache[type] = desc));
      }

      await Future.wait(futures);
      _isGenerated = true;
    } catch (e) {
      debugPrint('Error generating icons: $e');
    }
  }

  BitmapDescriptor? getIcon(String type) => _staticIconCache[type];
  BitmapDescriptor? getSelectedIcon(String type) =>
      _staticSelectedIconCache[type];
  BitmapDescriptor? getDefaultIcon() => _staticIconCache['default'];
  BitmapDescriptor? getDefaultSelectedIcon() =>
      _staticSelectedIconCache['default'];
}

class _BitmapGenerator {
  static Future<BitmapDescriptor> create(
      IconData icon, Color color, double size,
      {bool isSelected = false}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double center = size / 2;

    // Shadow
    final path = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(center, center), radius: center - 4));
    canvas.drawShadow(path, Colors.black.withOpacity(0.25), 4.0, true);

    // Background
    final bgPaint = Paint()..color = isSelected ? color : Colors.white;
    canvas.drawCircle(Offset(center, center), center - 4, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _iconBorderWidth;
    canvas.drawCircle(Offset(center, center), center - 6, borderPaint);

    // Icon
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.55,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: isSelected ? Colors.white : color,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }
}
