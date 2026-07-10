// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

// Characterization tests for [GemmaLocalService]. These pin the behavior that
// must survive the flutter_gemma 0.16.x -> 1.x migration. They assert against
// [ChatRuntimeGateway], our own seam, rather than flutter_gemma's statics, so
// they stay meaningful after the engine API changes underneath.
//
// Not covered: init(reloadInferenceWeights: true), which calls
// clearTfliteXnnpackWeightCaches() -> path_provider, unavailable in unit tests.

import 'package:disastron/features/chat/presentation/service/gemma_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_chat_runtime.dart';

void main() {
  late FakeChatRuntimeGateway gateway;
  late GemmaLocalService service;

  setUp(() {
    gateway = FakeChatRuntimeGateway();
    service = GemmaLocalService(runtime: gateway);
  });

  group('init', () {
    test('is not initialized before the first init', () {
      expect(service.isInitialized, isFalse);
    });

    test('loads the active model once and opens a chat', () async {
      await service.init(
        systemInstruction: 'sys',
        supportImage: true,
        maxNumImages: 3,
        loraPath: '/lora.bin',
      );

      expect(service.isInitialized, isTrue);
      expect(gateway.calls, hasLength(1));
      expect(gateway.calls.single.maxTokens, 2048);
      expect(gateway.calls.single.supportImage, isTrue);
      expect(gateway.calls.single.maxNumImages, 3);

      final FakeInferenceModel model = gateway.models.single;
      expect(model.createChatCalls, hasLength(1));
      expect(model.createChatCalls.single.systemInstruction, 'sys');
      expect(model.createChatCalls.single.supportImage, isTrue);
      expect(model.createChatCalls.single.loraPath, '/lora.bin');
    });

    test(
      'caps concurrent sessions to guard against a second KV cache',
      () async {
        await service.init();

        expect(gateway.calls.single.maxConcurrentSessions, 1);
      },
    );

    test(
      'forwards the active model type instead of defaulting to gemmaIt',
      () async {
        gateway.activeType = ModelType.gemma4;

        await service.init();

        // createChat() defaults an omitted modelType to gemmaIt, which would put
        // a gemma4 model on gemmaIt's thinking-filter branch.
        expect(
          gateway.models.single.createChatCalls.single.modelType,
          ModelType.gemma4,
        );
      },
    );

    test('passes a null model type through when none is active', () async {
      gateway.activeType = null;

      await service.init();

      expect(gateway.models.single.createChatCalls.single.modelType, isNull);
    });

    test('reuses the loaded model when the vision flag is unchanged', () async {
      await service.init(supportImage: true);
      await service.init(supportImage: true);

      expect(gateway.calls, hasLength(1), reason: 'weights reloaded');
      final FakeInferenceModel model = gateway.models.single;
      expect(model.closeCount, 0);
      expect(model.createChatCalls, hasLength(2));
    });

    test('closes the previous chat when re-initializing', () async {
      await service.init();
      await service.init();

      final FakeInferenceModel model = gateway.models.single;
      expect(model.chats, hasLength(2));
      expect(model.chats.first.closed, isTrue);
      expect(model.chats.last.closed, isFalse);
    });

    test('reloads the model when the vision flag flips', () async {
      await service.init(); // supportImage defaults to false
      await service.init(supportImage: true);

      expect(gateway.calls, hasLength(2));
      expect(gateway.models.first.closeCount, 1);
      expect(gateway.models.first.chats.single.closed, isTrue);
      expect(gateway.models.last.closeCount, 0);
    });

    test('does not reload on first init even with vision enabled', () async {
      await service.init(supportImage: true);

      expect(gateway.calls, hasLength(1));
      expect(gateway.models.single.closeCount, 0);
    });
  });

  group('processMessageAsync', () {
    setUp(() => service.init());

    test(
      'forwards the message unchanged when no device context is set',
      () async {
        final Message sent = Message.text(text: 'hello', isUser: true);
        await service.processMessageAsync(sent).drain<void>();

        final FakeInferenceChat chat = gateway.models.single.chats.single;
        expect(chat.queries.single.text, 'hello');
      },
    );

    test('streams the scripted model responses through', () async {
      gateway.models.single.chats.single.scriptedResponses = <ModelResponse>[
        const TextResponse('a'),
        const TextResponse('b'),
      ];

      final List<ModelResponse> got = await service
          .processMessageAsync(Message.text(text: 'hi', isUser: true))
          .toList();

      expect(
        got.whereType<TextResponse>().map((TextResponse r) => r.token),
        <String>['a', 'b'],
      );
    });

    test('prepends pending device context to the next turn only', () async {
      service.setDeviceContextForNextUserMessage('battery 42%');

      await service
          .processMessageAsync(Message.text(text: 'first', isUser: true))
          .drain<void>();
      await service
          .processMessageAsync(Message.text(text: 'second', isUser: true))
          .drain<void>();

      final FakeInferenceChat chat = gateway.models.single.chats.single;
      expect(chat.queries, hasLength(2));
      expect(chat.queries.first.text, contains('battery 42%'));
      expect(chat.queries.first.text, endsWith('first'));
      expect(chat.queries.first.isUser, isTrue);
      expect(chat.queries.last.text, 'second');
    });

    test('substitutes a marker for blank device context', () async {
      service.setDeviceContextForNextUserMessage('   ');

      await service
          .processMessageAsync(Message.text(text: 'q', isUser: true))
          .drain<void>();

      final FakeInferenceChat chat = gateway.models.single.chats.single;
      expect(chat.queries.single.text, contains('context_error: empty'));
    });
  });

  group('close', () {
    test('closes the chat and the model', () async {
      await service.init();
      final FakeInferenceModel model = gateway.models.single;

      await service.close();

      expect(service.isInitialized, isFalse);
      expect(model.chats.single.closed, isTrue);
      expect(model.closeCount, 1);
    });

    test('is a no-op when never initialized', () async {
      await expectLater(service.close(), completes);
      expect(gateway.calls, isEmpty);
    });

    test('drops pending device context', () async {
      await service.init();
      service.setDeviceContextForNextUserMessage('stale');
      await service.close();

      await service.init();
      await service
          .processMessageAsync(Message.text(text: 'fresh', isUser: true))
          .drain<void>();

      expect(gateway.models.last.chats.single.queries.single.text, 'fresh');
    });

    test('reloads the model on the next init', () async {
      await service.init();
      await service.close();
      await service.init();

      expect(gateway.calls, hasLength(2));
    });
  });
}
