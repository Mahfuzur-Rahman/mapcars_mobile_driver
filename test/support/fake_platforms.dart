// Test support: stand-ins for the two native plugins a driving-flow screen
// drags in — the Google map and the GPS — so a screen can be pumped as a whole
// in a widget test and its bottom sheet measured.
//
// The map is replaced by an empty box (a platform view can't exist in a widget
// test) and location permission reads as "permanently denied", so the map and
// the route tracker settle quietly instead of throwing on a missing plugin.
//
// Call [installFakeMapAndLocation] at the top of a test body (or `setUp`).

// These two packages are transitive (google_maps_flutter / geolocator), which is
// exactly why they are importable here: a fake platform has to extend them.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/services.dart' show PlatformViewCreatedCallback;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// What a test can do to the fake map once it is installed.
class FakeMap {
  FakeMap._(this._maps);
  final _FakeMaps _maps;

  /// The user dragging the map: what makes the follow camera give up and the
  /// "Re-centre" pill appear. Pump afterwards.
  void userPans() => _maps.emit(CameraMoveStartedEvent(_maps.mapId));
}

/// Replaces the maps and geolocator platforms for the current test and restores
/// the originals when it ends.
///
/// With no [fix], location permission reads as permanently denied. Pass a [fix]
/// for a screen that needs a position (it is granted and returned as the
/// current position; the live stream stays empty).
FakeMap installFakeMapAndLocation({Position? fix}) {
  final oldMaps = GoogleMapsFlutterPlatform.instance;
  final oldGeo = GeolocatorPlatform.instance;
  final maps = _FakeMaps();
  GoogleMapsFlutterPlatform.instance = maps;
  GeolocatorPlatform.instance = _FakeGeolocator(fix);
  addTearDown(() {
    GoogleMapsFlutterPlatform.instance = oldMaps;
    GeolocatorPlatform.instance = oldGeo;
  });
  return FakeMap._(maps);
}

class _FakeMaps extends GoogleMapsFlutterPlatform {
  final _events = StreamController<MapEvent<Object?>>.broadcast();
  int mapId = 0;
  final _created = <int>{};

  void emit(MapEvent<Object?> event) => _events.add(event);

  Stream<T> _of<T extends MapEvent<Object?>>() =>
      _events.stream.where((e) => e is T).cast<T>();

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    mapId = creationId;
    // The map "comes up" a moment later, as a real platform view does — once,
    // however many times the widget is rebuilt.
    if (_created.add(creationId)) {
      Future.microtask(() => onPlatformViewCreated(creationId));
    }
    return const SizedBox.expand();
  }

  // Everything the widget tells the native map is simply swallowed.
  @override
  Future<void> init(int mapId) async {}
  @override
  Future<void> updateMapConfiguration(MapConfiguration configuration,
          {required int mapId}) async {}
  @override
  Future<void> updateMarkers(MarkerUpdates markerUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updatePolylines(PolylineUpdates polylineUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updatePolygons(PolygonUpdates polygonUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updateCircles(CircleUpdates circleUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updateClusterManagers(ClusterManagerUpdates clusterManagerUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updateHeatmaps(HeatmapUpdates heatmapUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updateGroundOverlays(GroundOverlayUpdates groundOverlayUpdates,
          {required int mapId}) async {}
  @override
  Future<void> updateTileOverlays(
          {required Set<TileOverlay> newTileOverlays,
          required int mapId}) async {}
  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate,
          {required int mapId}) async {}
  @override
  Future<void> moveCamera(CameraUpdate cameraUpdate,
          {required int mapId}) async {}
  @override
  void dispose({required int mapId}) {}

  // The event streams the map controller subscribes to.
  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) =>
      _of<CameraMoveStartedEvent>();
  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) => _of();
  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) => _of();
  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) => _of();
  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) => _of();
  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) => _of();
  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) => _of();
  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) => _of();
  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) => _of();
  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) => _of();
  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) => _of();
  @override
  Stream<MapTapEvent> onTap({required int mapId}) => _of();
  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) => _of();
  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) => _of();
  @override
  Stream<GroundOverlayTapEvent> onGroundOverlayTap({required int mapId}) =>
      _of();
}

class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator(this._fix);

  final Position? _fix;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      _fix == null ? LocationPermission.deniedForever : LocationPermission.always;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async =>
      _fix ?? (throw const PermissionDeniedException('fake: no fix'));

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      const Stream<Position>.empty();
}
