part of 'wash_request_form_bloc.dart';

sealed class WashRequestFormEvent {
  const WashRequestFormEvent();
}

final class WashRequestFormSubmitted extends WashRequestFormEvent {
  const WashRequestFormSubmitted(this.draft);

  final WashRequestDraft draft;
}
