import 'user.dart';
import 'wash_request/wash_request.dart';
import 'wash_request/wash_status.dart';

enum ClientApplication { mobile, backoffice }

bool maySignIn(User user, ClientApplication application) => switch (application) {
  ClientApplication.mobile => user.role == Role.client || user.role == Role.washer,
  ClientApplication.backoffice => user.role.isStaff,
};

bool mayCreateRequest(User user) => user.role == Role.client;

bool mayViewAllRequests(User user) => user.role.isStaff;

bool mayAssignRequest(User user) => user.role.isStaff;

bool mayReleaseRequest(User user) => user.role.isStaff;

bool mayViewRequest(User user, WashRequest request) => switch (user.role) {
  Role.dispatcher => true,
  Role.client => request.clientId == user.id,
  Role.washer => switch (request.status) {
    Accepted(:final washerId) || InProgress(:final washerId) => washerId == user.washerId,
    _ => false,
  },
};

bool mayCancelRequest(User user, WashRequest request) =>
    user.role.isStaff || (user.role == Role.client && user.id == request.clientId && request.status is! InProgress);
