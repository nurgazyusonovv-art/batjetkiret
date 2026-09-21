import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/auth/presentation/auth_page.dart';
import 'package:frontend/features/auth/presentation/cubit/auth_cubit.dart';

class _TestAuthCubit extends AuthCubit {
  void completeAuthentication() {
    emit(
      state.copyWith(
        isInitialized: true,
        isLoading: false,
        token: 'authenticated-token',
        clearError: true,
      ),
    );
  }
}

class _RecordingAuthCubit extends AuthCubit {
  int submitCount = 0;
  String? submittedPhone;

  @override
  Future<void> submit({
    required String phone,
    required String password,
    String? name,
  }) async {
    submitCount++;
    submittedPhone = phone;
  }
}

void main() {
  testWidgets('guest auth page closes after successful authentication', (
    tester,
  ) async {
    final authCubit = _TestAuthCubit();
    addTearDown(authCubit.close);

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const Key('open-auth'),
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AuthPage())),
                child: const Text('Open auth'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-auth')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthPage), findsOneWidget);

    authCubit.completeAuthentication();
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsNothing);
    expect(find.byKey(const Key('open-auth')), findsOneWidget);
  });

  testWidgets('login button submits credentials on an iPad-sized screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authCubit = _RecordingAuthCubit();
    addTearDown(authCubit.close);

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: const MaterialApp(home: AuthPage()),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '558880871');
    await tester.enterText(fields.at(1), '123456!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Кирүү'));
    await tester.pump();

    expect(authCubit.submitCount, 1);
    expect(authCubit.submittedPhone, '+996558880871');
  });
}
