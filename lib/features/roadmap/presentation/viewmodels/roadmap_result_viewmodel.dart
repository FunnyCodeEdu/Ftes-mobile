import 'package:flutter/foundation.dart';
import '../../domain/entities/roadmap.dart';
import '../../domain/constants/roadmap_constants.dart';

class RoadmapResultViewModel extends ChangeNotifier {
  final Roadmap roadmap;

  RoadmapResultViewModel({required this.roadmap});

  // Simple getters for display
  List<String> get currentSkills => roadmap.currentSkills;
  List<RoadmapSkill> get skillsRoadMap => roadmap.skillsRoadMap;
  int get term => roadmap.term;
  GenerationParams get generationParams => roadmap.generationParams;

  String get specializationName {
    final params = roadmap.generationParams;
    // Find the enum value that maps to this specialization string
    final entry = RoadmapConstants.specializationMap.entries.firstWhere(
      (e) => e.value == params.specialization,
      orElse: () => const MapEntry('', ''),
    );
    return params.specialization;
  }
}
