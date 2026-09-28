/// Typed views over the trust API's JSON. Only what the screens read is
/// typed; everything else stays in [raw] so a new field never breaks parsing.
library;

String? _s(dynamic v) => v?.toString();

class TrustUser {
  const TrustUser({required this.id, required this.name, required this.email, this.phone, this.role, this.isSuperAdmin = false});

  factory TrustUser.fromJson(Map<String, dynamic> j) => TrustUser(
        id: j['id'] as int,
        name: '${j['name']}',
        email: '${j['email']}',
        phone: _s(j['phone']),
        role: _s(j['role']),
        isSuperAdmin: j['is_super_admin'] == true,
      );

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? role;

  /// Manages every temple and the approval queues.
  final bool isSuperAdmin;
}

class TrustTemple {
  const TrustTemple({
    required this.id,
    required this.name,
    required this.raw,
    this.slug,
    this.city,
    this.state,
    this.deity,
    this.statusLabel,
    this.trustLabel,
    this.accessLevel,
    this.imageUrl,
  });

  factory TrustTemple.fromJson(Map<String, dynamic> j) {
    final photo = j['primary_photo'];
    final urls = photo is Map ? photo['urls'] : null;
    return TrustTemple(
      id: j['id'] as int,
      name: '${j['name']}',
      slug: _s(j['slug']),
      city: _s(j['city']),
      state: _s(j['state']),
      deity: _s(j['deity']),
      statusLabel: _s((j['status'] as Map?)?['label']),
      trustLabel: _s((j['trust'] as Map?)?['label']),
      accessLevel: _s(j['access_level']),
      imageUrl: urls is Map ? _s(urls['medium'] ?? urls['original']) : null,
      raw: j,
    );
  }

  final int id;
  final String name;
  final String? slug;
  final String? city;
  final String? state;
  final String? deity;
  final String? statusLabel;
  final String? trustLabel;
  final String? accessLevel;
  final String? imageUrl;
  final Map<String, dynamic> raw;

  Map<String, dynamic> get profile => (raw['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get stats => (raw['stats'] as Map?)?.cast<String, dynamic>() ?? const {};

  String get place => [city, state].where((e) => e != null && e.isNotEmpty).join(', ');
}

class TempleClaim {
  const TempleClaim({required this.id, required this.status, this.templeName, this.templeCity, this.role, this.rejectionReason});

  factory TempleClaim.fromJson(Map<String, dynamic> j) {
    final t = j['temple'] as Map?;
    return TempleClaim(
      id: j['id'] as int,
      status: '${j['status']}',
      templeName: _s(t?['name']),
      templeCity: _s(t?['city']),
      role: _s(j['role']),
      rejectionReason: _s(j['rejection_reason']),
    );
  }

  final int id;
  final String status;
  final String? templeName;
  final String? templeCity;
  final String? role;
  final String? rejectionReason;
}

class TempleRegistration {
  const TempleRegistration({required this.id, required this.name, required this.status, required this.statusLabel, this.city, this.reviewNote});

  factory TempleRegistration.fromJson(Map<String, dynamic> j) {
    final st = j['status'] as Map?;
    return TempleRegistration(
      id: j['id'] as int,
      name: '${j['name']}',
      city: _s(j['city']),
      status: '${st?['value'] ?? 'pending'}',
      statusLabel: '${st?['label'] ?? 'Being reviewed'}',
      reviewNote: _s(j['review_note']),
    );
  }

  final int id;
  final String name;
  final String? city;
  final String status;
  final String statusLabel;
  final String? reviewNote;
}

class TrustAccount {
  const TrustAccount({required this.user, required this.temples, required this.claims, required this.registrations});

  factory TrustAccount.fromJson(Map<String, dynamic> j) => TrustAccount(
        user: TrustUser.fromJson((j['user'] as Map).cast<String, dynamic>()),
        temples: [for (final t in (j['temples'] as List? ?? const [])) TrustTemple.fromJson((t as Map).cast<String, dynamic>())],
        claims: [for (final c in (j['claims'] as List? ?? const [])) TempleClaim.fromJson((c as Map).cast<String, dynamic>())],
        registrations: [
          for (final r in (j['registrations'] as List? ?? const [])) TempleRegistration.fromJson((r as Map).cast<String, dynamic>())
        ],
      );

  final TrustUser user;
  final List<TrustTemple> temples;
  final List<TempleClaim> claims;
  final List<TempleRegistration> registrations;

  List<TempleClaim> get openClaims => claims.where((c) => c.status != 'approved').toList();
}

/// A value and label pair from `/trust/options`.
class Option {
  const Option(this.value, this.label);

  factory Option.fromJson(Map<String, dynamic> j) => Option(j['value'] ?? j['id'], '${j['label'] ?? j['name']}');

  final dynamic value;
  final String label;
}

/// Every choice list the forms need, loaded once per session.
class TrustOptions {
  const TrustOptions(this.raw);

  final Map<String, dynamic> raw;

  List<Option> list(String key) => [for (final o in (raw[key] as List? ?? const [])) Option.fromJson((o as Map).cast<String, dynamic>())];

  List<Option> get timingKinds => list('timing_kinds');
  List<Option> get eventTypes => list('event_types');
  List<Option> get pujaKinds => list('puja_kinds');
  List<Option> get photoCategories => list('photo_categories');
  List<Option> get days => list('days');
  List<Option> get claimLevels => list('claim_levels');
  List<Option> get registrationRoles => list('registration_roles');
  List<Option> get deities => list('deities');
  List<Option> get states => list('states');
  int get maxRegistrationPhotos => (raw['max_registration_photos'] as int?) ?? 8;
}
