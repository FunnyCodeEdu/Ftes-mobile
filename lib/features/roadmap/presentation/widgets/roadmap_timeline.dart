import 'package:flutter/material.dart';
import '../../domain/entities/roadmap.dart';
import 'roadmap_card.dart';

class RoadmapTimeline extends StatelessWidget {
  final List<RoadmapSkill> skills;
  const RoadmapTimeline({super.key, required this.skills});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(skills.length, (i) {
        final skill = skills[i];
        final isLast = i == skills.length - 1;
        final isFirst = i == 0;
        final isRecommended = isFirst;

        return Column(
          children: [
            // --- Timeline Dot & Line ---
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: vertical line + dot
                  SizedBox(
                    width: 48,
                    child: Column(
                      children: [
                        // Dot
                        _TimelineDot(
                          index: i,
                          isRecommended: isRecommended,
                          hasCourse: skill.slugName.isNotEmpty,
                        ),
                        // Line
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2.5,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF265DFF).withAlpha(180),
                                    Color(0xFF265DFF).withAlpha(80),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Right side: card
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: isLast ? 0 : 24,
                      ),
                      child: RoadmapCard(
                        skill: skill,
                        index: i,
                        isRecommended: isRecommended,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final int index;
  final bool isRecommended;
  final bool hasCourse;

  const _TimelineDot({
    required this.index,
    required this.isRecommended,
    required this.hasCourse,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 80),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isRecommended
              ? const LinearGradient(
                  colors: [Color(0xFF265DFF), Color(0xFF5B8DEF)],
                )
              : null,
          color: isRecommended ? null : Colors.white,
          border: Border.all(
            color: isRecommended ? Colors.transparent : const Color(0xFF265DFF),
            width: 2.5,
          ),
          boxShadow: [
            if (isRecommended)
              BoxShadow(
                color: const Color(0xFF265DFF).withAlpha(60),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            else
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: isRecommended
              ? const Icon(Icons.star, size: 18, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF265DFF),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}
