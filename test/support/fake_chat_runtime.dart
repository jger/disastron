// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'package:disastron/features/chat/presentation/service/chat_runtime_gateway.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Stand-in for [InferenceChat] that records queries and replays a scripted
/// response stream. [InferenceChat.sessionCreator] is nullable, so no
/// [InferenceModelSession] is ever built.
class FakeInferenceChat extends InferenceChat {
  FakeInferenceChat() : super(sessionCreator: null, maxTokens: 2048);

  /// Messages handed to [addQuery], in order.
  final List<Message> queries = <Message>[];

  /// Replayed by [generateChatResponseAsync].
  List<ModelResponse> scriptedResponses = <ModelResponse>[];

  bool closed = false;

  @override
  Future<void> addQuery(Message message) async => queries.add(message);

  @override
  Stream<ModelResponse> generateChatResponseAsync() =>
      Stream<ModelResponse>.fromIterable(scriptedResponses);

  @override
  Future<void> close() async => closed = true;
}

/// Stand-in for [InferenceModel]. Overrides [createChat] so the real one —
/// which builds an [InferenceChat] and opens a session — is never reached.
class FakeInferenceModel extends InferenceModel {
  /// Arguments of every [createChat] call, in order.
  final List<
    ({String? systemInstruction, bool? supportImage, String? loraPath})
  >
  createChatCalls =
      <({String? systemInstruction, bool? supportImage, String? loraPath})>[];

  /// Chats handed out by [createChat], in order.
  final List<FakeInferenceChat> chats = <FakeInferenceChat>[];

  int closeCount = 0;

  @override
  InferenceModelSession? get session => null;

  @override
  int get maxTokens => 2048;

  @override
  ModelFileType get fileType => ModelFileType.task;

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
  }) => throw UnimplementedError('FakeInferenceModel does not open sessions');

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
    bool isThinking = false,
    ModelType? modelType,
    ToolChoice toolChoice = ToolChoice.auto,
    int? maxFunctionBufferLength,
    String? systemInstruction,
  }) async {
    createChatCalls.add((
      systemInstruction: systemInstruction,
      supportImage: supportImage,
      loraPath: loraPath,
    ));
    final FakeInferenceChat created = FakeInferenceChat();
    chats.add(created);
    chat = created;
    return created;
  }

  @override
  Future<void> close() async => closeCount++;
}

/// Stand-in for [ChatRuntimeGateway]. Hands out a fresh [FakeInferenceModel]
/// per [getActiveModel] call so callers can assert how often weights reload.
class FakeChatRuntimeGateway implements ChatRuntimeGateway {
  /// Models handed out by [getActiveModel], in order.
  final List<FakeInferenceModel> models = <FakeInferenceModel>[];

  /// Arguments of every [getActiveModel] call, in order.
  final List<({int maxTokens, bool supportImage, int? maxNumImages})> calls =
      <({int maxTokens, bool supportImage, int? maxNumImages})>[];

  @override
  Future<InferenceModel> getActiveModel({
    required int maxTokens,
    bool supportImage = false,
    int? maxNumImages,
  }) async {
    calls.add((
      maxTokens: maxTokens,
      supportImage: supportImage,
      maxNumImages: maxNumImages,
    ));
    final FakeInferenceModel created = FakeInferenceModel();
    models.add(created);
    return created;
  }

  @override
  bool hasActiveModel() => models.isNotEmpty;
}
