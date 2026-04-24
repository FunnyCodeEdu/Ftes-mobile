import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/skills.dart';
import '../viewmodels/roadmap_viewmodel.dart';
import '../widgets/skill_chip.dart';
import '../widgets/gradient_button.dart';
import './roadmap_result_page.dart';
import 'package:ftes/core/widgets/bottom_navigation_bar.dart';
import '../../../../core/di/injection_container.dart' as di;

class RoadmapPage extends StatelessWidget {
  final bool hideBottomNav;

  const RoadmapPage({super.key, this.hideBottomNav = false});
  static final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final hideBottomNav = this.hideBottomNav;
    return ChangeNotifierProvider(
      create: (_) => di.sl<RoadmapViewModel>(),
      child: Consumer<RoadmapViewModel>(
        builder: (context, vm, _) {
          final theme = Theme.of(context);

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFF),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF8FAFF),
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF265DFF)),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Tạo Lộ Trình',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              centerTitle: true,
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Header Section ---
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF265DFF), Color(0xFF5B8DEF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF265DFF).withAlpha(60),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(50),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Lộ Trình Cá Nhân Hóa',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'AI tạo lộ trình tối ưu cho bạn',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Cung cấp thông tin để AI của chúng tôi tạo ra lộ trình học tập tối ưu nhất dành riêng cho bạn.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // --- Progress indicator ---
                        Row(
                          children: [
                            _ProgressStep(number: 1, label: 'Thông tin', isActive: true),
                            Expanded(child: Container(height: 2, color: const Color(0xFF265DFF).withAlpha(40))),
                            _ProgressStep(number: 2, label: 'Kỹ năng', isActive: false),
                            Expanded(child: Container(height: 2, color: Colors.grey.shade300)),
                            _ProgressStep(number: 3, label: 'Tạo roadmap', isActive: false),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // --- Form Title ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF265DFF).withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.school_outlined, color: Color(0xFF265DFF), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Thông Tin & Mục Tiêu',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF265DFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- Học kỳ ---
                        _SelectCard(
                          label: 'Học kỳ hiện tại',
                          icon: Icons.calendar_today_outlined,
                          child: DropdownButtonFormField<Semester>(
                            initialValue: vm.semester,
                            isExpanded: true,
                            items: Semester.values
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text('Học kỳ ${s.index + 1}'),
                                  ),
                                )
                                .toList(),
                            onChanged: vm.setSemester,
                            decoration: _inputDecoration(context, 'Chọn học kỳ'),
                            validator: (value) {
                              if (value == null) return 'Vui lòng chọn học kỳ';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Chuyên ngành ---
                        _SelectCard(
                          label: 'Chuyên ngành mục tiêu',
                          icon: Icons.track_changes_outlined,
                          child: DropdownButtonFormField<TargetMajor>(
                            initialValue: vm.target,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: TargetMajor.javaDeep, child: Text('Java chuyên sâu')),
                              DropdownMenuItem(value: TargetMajor.feDev, child: Text('Frontend Dev')),
                              DropdownMenuItem(value: TargetMajor.beDev, child: Text('Backend Dev')),
                              DropdownMenuItem(value: TargetMajor.fullstackDev, child: Text('Full-stack Dev')),
                              DropdownMenuItem(value: TargetMajor.mobileDev, child: Text('Mobile Dev')),
                            ],
                            onChanged: vm.setTarget,
                            decoration: _inputDecoration(context, 'Chọn chuyên ngành'),
                            validator: (value) {
                              if (value == null) return 'Vui lòng chọn chuyên ngành';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 28),

                        // --- Skills Section ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF265DFF).withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.psychology_outlined, color: Color(0xFF265DFF), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kỹ năng đã có (${vm.selectedSkillIds.length})',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF265DFF),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Chọn những kỹ năng bạn đã nắm vững',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Skill Chips ---
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: vm.allSkills
                                .map(
                                  (s) => SkillChip(
                                    label: s.label,
                                    selected: vm.selectedSkillIds.contains(s.id),
                                    onTap: () => vm.toggleSkill(s.id),
                                  ),
                                )
                                .toList(),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // --- Submit Button ---
                        GradientButton(
                          loading: vm.isGenerating,
                          label: 'Tạo Lộ Trình Ngay',
                          onPressed: () async {
                            final form = _formKey.currentState!;
                            if (form.validate()) {
                              final roadmap = await vm.submit(context);
                              if (roadmap != null && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RoadmapResultPage(roadmap: roadmap),
                                  ),
                                );
                              } else if (vm.errorMessage != null && context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.error_outline, color: Colors.red.shade400),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Lỗi'),
                                      ],
                                    ),
                                    content: Text(vm.errorMessage!),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: hideBottomNav ? null : AppBottomNavigationBar(selectedIndex: 2),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF265DFF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _SelectCard({required this.label, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF265DFF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final int number;
  final String label;
  final bool isActive;

  const _ProgressStep({required this.number, required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFF265DFF) : Colors.grey.shade300,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? const Color(0xFF265DFF) : Colors.grey,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
