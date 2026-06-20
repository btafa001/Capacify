import 'dart:math' as math;

class LocationService {
  // Calculate distance between two coordinates using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth radius in kilometers
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double degree) {
    return degree * math.pi / 180;
  }

  // Hamburg default coordinates
  static const double hamburgLat = 53.5511;
  static const double hamburgLon = 9.9937;

  // Get default coordinates for Hamburg
  static Map<String, double> getHamburgCoordinates() {
    return {
      'latitude': hamburgLat,
      'longitude': hamburgLon,
    };
  }

  // District centroids — keys match kHamburgDistricts in app_constants.dart
  static Map<String, Map<String, double>> getHamburgDistricts() {
    return {
      'Eimsbüttel': {'latitude': 53.5735, 'longitude': 9.9600},
      'Altona': {'latitude': 53.5495, 'longitude': 9.9351},
      'Wandsbek': {'latitude': 53.5890, 'longitude': 10.0744},
      'Hamburg Mitte': {'latitude': 53.5511, 'longitude': 9.9937},
      'Harburg': {'latitude': 53.4618, 'longitude': 9.9852},
      'Bergedorf': {'latitude': 53.4848, 'longitude': 10.2789},
      'Hamburg Nord': {'latitude': 53.5980, 'longitude': 10.0296},
      'Billstedt': {'latitude': 53.5304, 'longitude': 10.1748},
      'Barmbek-Nord': {'latitude': 53.6127, 'longitude': 10.0711},
      'Uhlenhorst': {'latitude': 53.5727, 'longitude': 10.0589},
      'Rahlstedt': {'latitude': 53.6000, 'longitude': 10.1500},
      'Bramfeld': {'latitude': 53.6086, 'longitude': 10.0725},
      'Lurup': {'latitude': 53.5931, 'longitude': 9.8828},
      'Bahrenfeld': {'latitude': 53.5670, 'longitude': 9.8830},
      'Niendorf': {'latitude': 53.6178, 'longitude': 9.9503},
    };
  }

  // Postal code (PLZ) → district name, for resolving a company's own
  // postal code to the same district vocabulary used by capacity listings.
  static const Map<String, String> _postalCodeToDistrict = {
    // Hamburg Mitte
    '20095': 'Hamburg Mitte', '20097': 'Hamburg Mitte', '20099': 'Hamburg Mitte',
    '20354': 'Hamburg Mitte', '20355': 'Hamburg Mitte', '20359': 'Hamburg Mitte',
    '20457': 'Hamburg Mitte', '20459': 'Hamburg Mitte',
    // Altona
    '22765': 'Altona', '22767': 'Altona', '22769': 'Altona',
    // Eimsbüttel
    '20144': 'Eimsbüttel', '20253': 'Eimsbüttel', '20255': 'Eimsbüttel',
    '20257': 'Eimsbüttel', '20259': 'Eimsbüttel', '20357': 'Eimsbüttel',
    '22527': 'Eimsbüttel',
    // Wandsbek
    '22041': 'Wandsbek', '22049': 'Wandsbek', '22089': 'Wandsbek',
    // Bergedorf
    '21033': 'Bergedorf', '21035': 'Bergedorf',
    // Harburg
    '21075': 'Harburg', '21079': 'Harburg',
    // Hamburg Nord
    '22297': 'Hamburg Nord',
    // Billstedt
    '22111': 'Billstedt', '22115': 'Billstedt', '22117': 'Billstedt', '22119': 'Billstedt',
    // Barmbek-Nord
    '22305': 'Barmbek-Nord', '22307': 'Barmbek-Nord', '22309': 'Barmbek-Nord',
    // Uhlenhorst
    '22081': 'Uhlenhorst', '22085': 'Uhlenhorst', '22087': 'Uhlenhorst',
    // Rahlstedt
    '22143': 'Rahlstedt', '22147': 'Rahlstedt', '22149': 'Rahlstedt', '22359': 'Rahlstedt',
    // Bramfeld
    '22047': 'Bramfeld', '22159': 'Bramfeld', '22175': 'Bramfeld',
    '22179': 'Bramfeld', '22391': 'Bramfeld', '22393': 'Bramfeld',
    // Lurup
    '22525': 'Lurup', '22547': 'Lurup', '22549': 'Lurup',
    // Bahrenfeld
    '22607': 'Bahrenfeld', '22761': 'Bahrenfeld',
    // Niendorf
    '22453': 'Niendorf', '22455': 'Niendorf', '22457': 'Niendorf',
    '22459': 'Niendorf', '22529': 'Niendorf',
  };

  // Resolve a postal code to its district's centroid coordinates.
  static Map<String, double>? coordinatesForPostalCode(String postalCode) {
    final district = _postalCodeToDistrict[postalCode.trim()];
    if (district == null) return null;
    return getHamburgDistricts()[district];
  }

  // Distance from a company's postal code to a capacity's district.
  static double estimateDistanceFromPostalCode(
    String fromPostalCode,
    String toDistrict,
  ) {
    final fromCoords = coordinatesForPostalCode(fromPostalCode);
    final toCoords = getHamburgDistricts()[toDistrict];

    if (fromCoords == null || toCoords == null) {
      return 999;
    }

    return calculateDistance(
      fromCoords['latitude']!,
      fromCoords['longitude']!,
      toCoords['latitude']!,
      toCoords['longitude']!,
    );
  }
}
