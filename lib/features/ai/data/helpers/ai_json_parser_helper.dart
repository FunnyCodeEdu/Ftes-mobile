import 'dart:convert';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import '../../domain/entities/ai_chat_message.dart';
import '../models/ai_chat_response_model.dart';
import '../../domain/constants/ai_constants.dart';

/// Helper for parsing AI chat JSON responses off main thread
class AiJsonParserHelper {
  /// Parse AI chat response JSON
  /// Uses isolate if response is large
  static Future<AiChatMessage> parseAiChatResponse(
    Map<String, dynamic> json,
  ) async {
    try {
      final response = AiChatResponseModel.fromJson(json);
      
      if (response.success) {
        final answer = response.getAnswer();
        
        if (answer != null && answer.isNotEmpty) {
          return AiChatMessage.ai(answer);
        } else {
          throw Exception(AiConstants.errorEmptyResponse);
        }
      } else {
        final errorMsg = (response.error?.isNotEmpty == true)
            ? response.error!
            : (response.message.isNotEmpty
                ? response.message
                : AiConstants.errorSendMessageFailed);
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ Parse AI response error: $e');
      rethrow;
    }
  }

  /// Parse JSON using isolate for large responses
  static Future<AiChatMessage> parseAiChatResponseInIsolate(
    Map<String, dynamic> json,
  ) async {
    try {
      final jsonString = jsonEncode(json);
      final jsonSize = jsonString.length;

      debugPrint('📊 JSON size: $jsonSize bytes');

      if (jsonSize > AiConstants.jsonParsingThreshold) {
        debugPrint('⚡ Using compute isolate for JSON parsing (${jsonSize}B > ${AiConstants.jsonParsingThreshold}B)');

        // Isolate returns Map, convert to AiChatMessage on main thread
        final result = await compute(
          _parseAiChatResponseInIsolate,
          json,
        );

        if (result != null) {
          return AiChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: result['content'] as String,
            timestamp: DateTime.now(),
            isFromUser: false,
            type: AiMessageType.text,
          );
        } else {
          throw Exception('Isolate returned null');
        }
      } else {
        debugPrint('⚡ Parsing JSON on main thread (${jsonSize}B <= ${AiConstants.jsonParsingThreshold}B)');
        return parseAiChatResponse(json);
      }
    } catch (e) {
      debugPrint('❌ Parse JSON error: $e');
      rethrow;
    }
  }
}

/// Isolate function for parsing AI response (returns simple Map for serialization)
Map<String, dynamic>? _parseAiChatResponseInIsolate(Map<String, dynamic> json) {
  try {
    final response = AiChatResponseModel.fromJson(json);

    if (response.success) {
      final answer = response.getAnswer();

      if (answer != null && answer.isNotEmpty) {
        // ignore: avoid_print
        print('Isolate: answer found, length=${answer.length}');
        return {
          'content': answer,
          'isFromUser': false,
        };
      } else {
        // ignore: avoid_print
        print('Isolate: answer is null or empty');
        throw Exception(AiConstants.errorEmptyResponse);
      }
    } else {
      final errorMsg = (response.error?.isNotEmpty == true)
          ? response.error!
          : (response.message.isNotEmpty
              ? response.message
              : AiConstants.errorSendMessageFailed);
      // ignore: avoid_print
      print('Isolate: success=false, error=$errorMsg');
      throw Exception(errorMsg);
    }
  } catch (e) {
    // ignore: avoid_print
    print('Parse AI response in isolate error: $e');
    rethrow;
  }
}
