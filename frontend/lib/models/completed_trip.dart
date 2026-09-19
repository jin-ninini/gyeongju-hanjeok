import 'place.dart';
import 'route_plan.dart';

class CompletedTrip {
  const CompletedTrip({
    required this.id,
    required this.route,
    required this.completedAt,
  });

  final String id;
  final RoutePlan route;
  final DateTime completedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'completed_at': completedAt.toIso8601String(),
      'route': {
        'id': route.id,
        'title': route.title,
        'summary': route.summary,
        'total_minutes': route.totalMinutes,
        'total_distance_km': route.totalDistanceKm,
        'average_quiet_score': route.averageQuietScore,
        'updated_at': route.updatedAt.toIso8601String(),
        'weather_summary': route.weatherSummary,
        'stops': route.stops
            .map(
              (stop) => {
                'order': stop.order,
                'arrival_time': stop.arrivalTime,
                'stay_minutes': stop.stayMinutes,
                'travel_minutes': stop.travelMinutes,
                'transport_instruction': stop.transportInstruction,
                'is_rest_stop': stop.isRestStop,
                'place': _placeToJson(stop.place),
              },
            )
            .toList(),
      },
    };
  }

  factory CompletedTrip.fromJson(
    Map<String, dynamic> json,
  ) {
    final routeJson = json['route'] is Map
        ? Map<String, dynamic>.from(
            json['route'] as Map,
          )
        : const <String, dynamic>{};

    return CompletedTrip(
      id: (json['id'] ?? '').toString(),
      route: RoutePlan.fromJson(routeJson),
      completedAt: DateTime.tryParse(
            (json['completed_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }
}

Map<String, dynamic> _placeToJson(
  Place place,
) {
  return {
    'id': place.id,
    'place_id': place.id,
    'content_type_id': place.contentTypeId,
    'name': place.name,
    'title': place.name,
    'address': place.address,
    'latitude': place.latitude,
    'longitude': place.longitude,
    'quiet_score': place.quietScore,
    'category': place.category,
    'description': place.description,
    'image_url': place.imageUrl,
    'image_asset': place.imageAsset,
    'distance_km': place.distanceKm,
    'recommended_time': place.recommendedTime,
    'stay_minutes': place.stayMinutes,
    'is_paid': place.isPaid,
    'etiquette': place.etiquette,
    'content_links': place.contentLinks
        .map(
          (link) => {
            'title': link.title,
            'url': link.url,
            'type': link.type,
          },
        )
        .toList(),
  };
}
