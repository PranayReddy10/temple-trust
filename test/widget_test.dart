import 'package:flutter_test/flutter_test.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/models.dart';

void main() {
  test('account parses temples, claims and registrations', () {
    final account = TrustAccount.fromJson({
      'user': {'id': 1, 'name': 'Trust Secretary', 'email': 's@example.org', 'phone': '9876543210'},
      'temples': [
        {
          'id': 7,
          'name': 'Sri Rama Temple',
          'city': 'Bhadrachalam',
          'state': 'Telangana',
          'status': {'value': 'published', 'label': 'Published'},
          'trust': {'value': 'community', 'label': 'Community'},
          'profile': {'contact_phone': '08743 232428'},
        }
      ],
      'claims': [
        {'id': 3, 'status': 'pending', 'temple': {'id': 9, 'name': 'Another'}},
        {'id': 4, 'status': 'approved', 'temple': {'id': 7, 'name': 'Sri Rama Temple'}},
      ],
      'registrations': [
        {'id': 2, 'name': 'Village Temple', 'status': {'value': 'pending', 'label': 'Being reviewed'}},
      ],
    });

    expect(account.temples.single.place, 'Bhadrachalam, Telangana');
    expect(account.temples.single.profile['contact_phone'], '08743 232428');
    expect(account.openClaims.map((c) => c.id), [3]);
    expect(account.registrations.single.statusLabel, 'Being reviewed');
  });

  test('a super admin is recognised from the account', () {
    final admin = TrustUser.fromJson({'id': 1, 'name': 'Admin', 'email': 'a@example.org', 'role': 'super_admin', 'is_super_admin': true});
    final team = TrustUser.fromJson({'id': 2, 'name': 'Team', 'email': 't@example.org', 'role': 'temple_admin'});
    expect(admin.isSuperAdmin, isTrue);
    expect(team.isSuperAdmin, isFalse);
  });

  test('validation errors read field by field', () {
    const e = ApiException('Invalid', statusCode: 422, errors: {'email': ['Taken.']});
    expect(e.isValidation, isTrue);
    expect(e.field('email'), 'Taken.');
    expect(e.details, 'Taken.');
  });
}
