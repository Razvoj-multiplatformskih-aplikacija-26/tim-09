import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  test('backoffice je dostupan samo dispečeru', () {
    expect(maySignIn(client, ClientApplication.backoffice), isFalse);
    expect(maySignIn(dispatcher, ClientApplication.backoffice), isTrue);
    expect(maySignIn(client, ClientApplication.mobile), isTrue);
    expect(mayAssignRequest(client), isFalse);
    expect(mayReleaseRequest(client), isFalse);
  });

  test('perač ne dobija klijentska prava ni kada se identifikator poklopi', () {
    final washer = User(id: client.id, username: 'perač', role: Role.washer);
    final own = requestAt(now.add(const Duration(days: 1)));
    expect(mayCancel(washer, own), isFalse);
    expect(mayCreateRequest(washer), isFalse);
  });

  test('dodeljeni posao vidi samo odgovarajući perač', () {
    const washer = User(id: UserId('washer-user'), username: 'nikola', role: Role.washer, washerId: WasherId('w-1'));
    final assigned = requestAt(now.add(const Duration(days: 1))).copyWith(
      status: Accepted(washerId: const WasherId('w-1'), acceptedBy: dispatcher.id, at: now),
    );
    expect(mayViewRequest(washer, assigned), isTrue);
    expect(mayViewRequest(washer, requestAt(now.add(const Duration(days: 1)))), isFalse);
    expect(mayCancelRequest(washer, assigned), isFalse);
  });
}
