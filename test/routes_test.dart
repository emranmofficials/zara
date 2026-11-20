import 'package:flutter_test/flutter_test.dart';
import 'package:zara/core/navigation/route_meta.dart';
import 'package:zara/core/navigation/routes.dart';
import 'package:zara/features/system/info_screen.dart';

void main() {
  group('route catalogue', () {
    test('contains the full route table with metadata for every address', () {
      expect(Routes.all.length, greaterThanOrEqualTo(50));
      expect(Routes.all.toSet().length, Routes.all.length);
      for (final route in Routes.all) {
        expect(RouteCatalog.find(route), isNotNull, reason: route);
        expect(RouteRegistry.has(route), isTrue, reason: route);
      }
    });

    test('voice phrases resolve, longest alias first', () {
      expect(RouteRegistry.resolveFromPhrase('zara home'), Routes.zaraHome);
      expect(RouteRegistry.resolveFromPhrase('open settings'), Routes.settings);
      expect(RouteRegistry.resolveFromPhrase('yaad dikhao'), Routes.yaadein);
      expect(RouteRegistry.resolveFromPhrase('scan karo'), Routes.scanner);
      expect(RouteRegistry.resolveFromPhrase('unknown'), isNull);
    });

    test('every route maps to a real UI (feature screen or info screen)', () {
      for (final route in Routes.all) {
        final widget = RoutePage.forRoute(route);
        final isLegal = RouteCatalog.find(route)?.group == RouteGroup.legal;
        if (isLegal && route != Routes.permissions) {
          expect(widget, isA<InfoScreen>(), reason: route);
        } else {
          expect(widget, isNot(isA<InfoScreen>()), reason: route);
        }
      }
    });

    test('bottom destinations map back to stable indices', () {
      expect(RouteRegistry.destinations.length, 5);
      for (var i = 0; i < RouteRegistry.destinations.length; i++) {
        final route = RouteRegistry.routeFor(i);
        expect(RouteRegistry.indexFor(route), i);
      }
    });
  });
}
