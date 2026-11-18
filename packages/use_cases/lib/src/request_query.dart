import 'package:domain/domain.dart';
import 'package:meta/meta.dart';

enum RequestScope { mine, all }

enum RequestStatusFilter { submitted, accepted, inProgress, completed, cancelled }

bool matchesStatusFilter(WashStatus status, RequestStatusFilter? filter) => switch (filter) {
  null => true,
  RequestStatusFilter.submitted => status is Submitted,
  RequestStatusFilter.accepted => status is Accepted,
  RequestStatusFilter.inProgress => status is InProgress,
  RequestStatusFilter.completed => status is Completed,
  RequestStatusFilter.cancelled => status is Cancelled,
};

@immutable
final class RequestQuery {
  const RequestQuery({required this.scope, this.limit = 20, this.offset = 0, this.status})
    : assert(limit >= 1 && limit <= maxLimit),
      assert(offset >= 0);

  static const maxLimit = 100;

  final RequestScope scope;
  final int limit;
  final int offset;
  final RequestStatusFilter? status;

  @override
  bool operator ==(Object other) =>
      other is RequestQuery &&
      other.scope == scope &&
      other.limit == limit &&
      other.offset == offset &&
      other.status == status;

  @override
  int get hashCode => Object.hash(scope, limit, offset, status);

  @override
  String toString() => 'RequestQuery(${scope.name}, offset $offset, limit $limit, ${status?.name ?? 'any'})';
}

@immutable
final class RequestPage {
  RequestPage({required List<WashRequest> items, required this.total, required this.limit, required this.offset})
    : items = List.unmodifiable(items);

  final List<WashRequest> items;
  final int total;
  final int limit;
  final int offset;

  bool get isEmpty => items.isEmpty;

  bool get hasPrevious => offset > 0;

  bool get hasNext => offset + items.length < total;

  int get previousOffset => offset - limit < 0 ? 0 : offset - limit;

  int get nextOffset => offset + limit;

  int get lastOffset => total == 0 ? 0 : ((total - 1) ~/ limit) * limit;

  bool get isPastEnd => items.isEmpty && total > 0 && offset > 0;

  int get firstNumber => items.isEmpty ? 0 : offset + 1;

  int get lastNumber => offset + items.length;

  @override
  bool operator ==(Object other) =>
      other is RequestPage &&
      other.total == total &&
      other.limit == limit &&
      other.offset == offset &&
      _sameItems(other.items, items);

  static bool _sameItems(List<WashRequest> a, List<WashRequest> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), total, limit, offset);

  @override
  String toString() => 'RequestPage(${items.length} of $total at $offset)';
}
