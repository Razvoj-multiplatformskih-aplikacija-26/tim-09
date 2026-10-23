part of 'wash_request_form_bloc.dart';

sealed class WashRequestFormState extends Equatable {
  const WashRequestFormState();

  @override
  List<Object?> get props => const [];

  @override
  String toString() => '$runtimeType';
}

final class WashRequestFormEditing extends WashRequestFormState {
  const WashRequestFormEditing();
}

final class WashRequestFormSubmitting extends WashRequestFormState {
  const WashRequestFormSubmitting();
}

final class WashRequestFormDone extends WashRequestFormState {
  const WashRequestFormDone(this.request);

  final WashRequest request;

  @override
  List<Object?> get props => [request];
}

/// Domen je odbio zahtev (npr. R6, previše zahteva na čekanju).
final class WashRequestFormRejected extends WashRequestFormState {
  const WashRequestFormRejected(this.error);

  final DomainError error;

  @override
  List<Object?> get props => [error];
}

/// Repozitorijum nije odgovorio (simulirana greška).
final class WashRequestFormFailed extends WashRequestFormState {
  const WashRequestFormFailed(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];
}
