import 'package:flutter/material.dart';
import '../../domain/entities/roadmap.dart';
import '../../../../core/constants/app_constants.dart';

class RoadmapCard extends StatefulWidget {
  final RoadmapSkill skill;
  final int index;
  final bool isRecommended;

  const RoadmapCard({
    super.key,
    required this.skill,
    required this.index,
    this.isRecommended = false,
  });

  @override
  State<RoadmapCard> createState() => _RoadmapCardState();
}

class _RoadmapCardState extends State<RoadmapCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  String get _shortDescription {
    final desc = widget.skill.description;
    if (desc.length <= 150) return desc;
    return '${desc.substring(0, 150)}...';
  }

  bool get _hasLongDescription => widget.skill.description.length > 150;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCourse = widget.skill.slugName.isNotEmpty;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + widget.index * 100),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: widget.isRecommended
              ? Border.all(color: const Color(0xFF265DFF), width: 2)
              : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: widget.isRecommended
                  ? const Color(0xFF265DFF).withAlpha(30)
                  : Colors.black.withAlpha(15),
              blurRadius: widget.isRecommended ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: widget.isRecommended
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF265DFF).withAlpha(10),
                          Colors.transparent,
                        ],
                      )
                    : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row: Title + Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.skill.skill,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A2E),
                            fontSize: 16,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF265DFF), Color(0xFF5B8DEF)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF265DFF).withAlpha(50),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Bắt đầu tại đây',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description
                  GestureDetector(
                    onTap: _hasLongDescription ? _toggleExpanded : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedCrossFade(
                          firstChild: Text(
                            _shortDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                          secondChild: Text(
                            widget.skill.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                          crossFadeState: _isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                        if (_hasLongDescription) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                _isExpanded ? Icons.expand_less : Icons.expand_more,
                                size: 18,
                                color: const Color(0xFF265DFF),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isExpanded ? 'Thu gọn' : 'Xem thêm',
                                style: const TextStyle(
                                  color: Color(0xFF265DFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- Divider ---
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.grey.shade100,
            ),

            // --- Footer ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Term badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Học kỳ ${widget.skill.term}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Course button
                  Expanded(
                    child: hasCourse
                        ? ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppConstants.routeCourseDetail,
                                arguments: widget.skill.slugName,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF265DFF),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_outline, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Xem khóa học',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : OutlinedButton(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.schedule, size: 16, color: Colors.grey.shade400),
                                const SizedBox(width: 6),
                                Text(
                                  'Sắp có khóa học',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
