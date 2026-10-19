// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:async';

import 'package:disastron/features/chat/data/chat_runtime_gateway.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// Stand-in for [InferenceChat] that records queries and replays a scripted
/// response stream. [InferenceChat.sessionCreator] is nullable, so no
/// [InferenceModelSession] is ever built.
class FakeInferenceChat extends InferenceChat {
  FakeInferenceChat() : super(sessionCreator: null, maxTokens: 2048);

  /// Messages handed to [addQuery], in order.
  final List<Message> queries = <Message>[];

  /// Replayed by [generateChatResponseAsync].
  List<ModelResponse> scriptedResponses = <ModelResponse>[];

  /// When set, [generateChatResponseWithTools] invokes this then appends
  /// [scriptedResponsesAfterTool].
  Future<Map<String, dynamic>> Function(FunctionCallResponse call)?
  onToolCallScript;

  List<ModelResponse> scriptedResponsesAfterTool = <ModelResponse>[];

  bool closed = false;

  int clearHistoryCallCount = 0;

  List<Message>? lastClearHistoryReplay;

  @override
  Future<void> addQuery(Message message) async => queries.add(message);

  @override
  Stream<ModelResponse> generateChatResponseAsync() =>
      Stream<ModelResponse>.fromIterable(scriptedResponses);

  @override
  Stream<ModelResponse> generateChatResponseWithTools({
    required FutureOr<Map<String, dynamic>> Function(FunctionCallResponse call)
    onToolCall,
    int maxToolTurns = 8,
    bool Function()? isCancelled,
    void Function()? onMaxToolTurns,
  }) async* {
    for (final ModelResponse r in scriptedResponses) {
      if (r is FunctionCallResponse) {
        await onToolCall(r);
        yield* Stream<ModelResponse>.fromIterable(scriptedResponsesAfterTool);
        return;
      }
      yield r;
    }
    if (onToolCallScript != null) {
      const FunctionCallResponse synthetic = FunctionCallResponse(
        name: 'update_checklist',
        args: <String, dynamic>{
          'ops': <Map<String, dynamic>>[
            <String, dynamic>{'op': 'add', 'title': 'test'},
          ],
        },
      );
      await onToolCall(synthetic);
      yield* Stream<ModelResponse>.fromIterable(scriptedResponsesAfterTool);
    }
  }

  @override
  Future<void> clearHistory({List<Message>? replayHistory}) async {
    clearHistoryCallCount++;
    lastClearHistoryReplay = replayHistory;
  }

  @override
  Future<void> close() async => closed = true;
}

/// Stand-in for [InferenceModel]. Overrides [createChat] so the real one —
/// which builds an [InferenceChat] and opens a session — is never reached.
class FakeInferenceModel extends InferenceModel {
  FakeInferenceModel({this.fileType = ModelFileType.litertlm});

  /// Arguments of every [createChat] call, in order.
  final List<
    ({
      String? systemInstruction,
      bool? supportImage,
      String? loraPath,
      ModelType? modelType,
      List<Tool> tools,
      bool? supportsFunctionCalls,
      bool enableThinking,
      int? maxOutputTokens,
    })
  >
  createChatCalls =
      <
        ({
          String? systemInstruction,
          bool? supportImage,
          String? loraPath,
          ModelType? modelType,
          List<Tool> tools,
          bool? supportsFunctionCalls,
          bool enableThinking,
          int? maxOutputTokens,
        })
      >[];

  /// Chats handed out by [createChat], in order.
  final List<FakeInferenceChat> chats = <FakeInferenceChat>[];

  final List<void Function()> _closeListeners = <void Function()>[];

  int closeCount = 0;

  @override
  final ModelFileType fileType;

  @override
  InferenceModelSession? get session => null;

  @override
  int get maxTokens => 2048;

  @override
  PreferredBackend? get activeBackend => null;

  @override
  Future<InferenceModelSession> createSession({
    double temperature = .8,
    int randomSeed = 1,
    int topK = 1,
    double? topP,
    String? loraPath,
    bool? enableVisionModality,
    bool? enableAudioModality,
    String? systemInstruction,
    bool enableThinking = false,
    List<Tool> tools = const <Tool>[],
    int? maxOutputTokens,
  }) => throw UnimplementedError('FakeInferenceModel does not open sessions');

  /// Core registers a listener here to reset its singleton bookkeeping when an
  /// engine-built model closes. Fired by [close].
  @override
  void addCloseListener(void Function() listener) =>
      _closeListeners.add(listener);

  @override
  Future<InferenceChat> createChat({
    double temperature = .8,
    int randomSeed = 1,
    int topK = 1,
    double? topP,
    int tokenBuffer = 256,
    String? loraPath,
    bool? supportImage,
    bool? supportAudio,
    List<Tool> tools = const <Tool>[],
    bool? supportsFunctionCalls,
    bool enableThinking = false,
    ModelType? modelType,
    ToolChoice toolChoice = ToolChoice.auto,
    int? maxFunctionBufferLength,
    String? systemInstruction,
    int? maxOutputTokens,
  }) async {
    createChatCalls.add((
      systemInstruction: systemInstruction,
      supportImage: supportImage,
      loraPath: loraPath,
      modelType: modelType,
      tools: tools,
      supportsFunctionCalls: supportsFunctionCalls,
      enableThinking: enableThinking,
      maxOutputTokens: maxOutputTokens,
    ));
    final FakeInferenceChat created = FakeInferenceChat();
    chats.add(created);
    chat = created;
    return created;
  }

  @override
  Future<void> close() async {
    closeCount++;
    for (final void Function() listener in _closeListeners) {
      listener();
    }
  }
}

/// Stand-in for [ChatRuntimeGateway]. Hands out a fresh [FakeInferenceModel]
/// per [getActiveModel] call so callers can assert how often weights reload.
class FakeChatRuntimeGateway implements ChatRuntimeGateway {
  /// Models handed out by [getActiveModel], in order.
  final List<FakeInferenceModel> models = <FakeInferenceModel>[];

  /// Arguments of every [getActiveModel] call, in order.
  final List<
    ({
      int maxTokens,
      bool supportImage,
      int? maxNumImages,
      int? maxConcurrentSessions,
    })
  >
  calls =
      <
        ({
          int maxTokens,
          bool supportImage,
          int? maxNumImages,
          int? maxConcurrentSessions,
        })
      >[];

  ModelFileType fakeFileType = ModelFileType.litertlm;

  @override
  Future<InferenceModel> getActiveModel({
    required int maxTokens,
    bool supportImage = false,
    int? maxNumImages,
    int? maxConcurrentSessions,
  }) async {
    calls.add((
      maxTokens: maxTokens,
      supportImage: supportImage,
      maxNumImages: maxNumImages,
      maxConcurrentSessions: maxConcurrentSessions,
    ));
    final FakeInferenceModel created = FakeInferenceModel(
      fileType: fakeFileType,
    );
    models.add(created);
    return created;
  }

  /// Returned by [activeModelType]; mirrors the real gateway reading the
  /// plugin's active [InferenceModelSpec].
  ModelType? activeType = ModelType.gemma4;

  @override
  ModelType? activeModelType() => activeType;
}
