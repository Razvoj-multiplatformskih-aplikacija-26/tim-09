import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:use_cases/use_cases.dart';

part 'wash_request_form_event.dart';
part 'wash_request_form_state.dart';

/// Lokalni Bloc forme „Novi zahtev“: šalje već proveren nacrt i javlja ishod.
/// Polja forme proverava domen (`parse`) u samom ekranu, pri unosu.
final class WashRequestFormBloc extends Bloc<WashRequestFormEvent, WashRequestFormState> {
  WashRequestFormBloc({required this.submitRequest}) : super(const WashRequestFormEditing()) {
    on<WashRequestFormSubmitted>((event, emit) async {
      emit(const WashRequestFormSubmitting());
      try {
        final result = await submitRequest(event.draft);
        switch (result) {
          case Success(:final value):
            emit(WashRequestFormDone(value));
          case Failure(:final error):
            emit(WashRequestFormRejected(error));
        }
      } on Exception catch (cause) {
        emit(WashRequestFormFailed(cause));
      }
    });
  }

  final SubmitRequest submitRequest;
}
