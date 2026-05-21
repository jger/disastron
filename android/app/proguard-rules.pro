# MediaPipe / LiteRT: optional protobuf types (profiling, graph templates) not shipped; R8 still requires these rules.
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

# flutter_gemma 0.15.2+ dropped localagents-rag/Guava; MediaPipe still references AutoValue Memoized at compile time.
-dontwarn com.google.auto.value.extension.memoized.Memoized
