import 'dart:ui';
import 'package:flutter/material.dart';

void main() => runApp(const NaseemApp());

const Color _background = Color(0xFF0B1220);
const Color _mint = Color(0xFF9BE5D8);
const Color _lavender = Color(0xFFC5B8FF);
const Color _softBlue = Color(0xFF9BCBFF);
const Color _peach = Color(0xFFFFCBAA);

class NaseemApp extends StatelessWidget {
  const NaseemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نسيم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _mint,
          brightness: Brightness.dark,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF253246),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppShell(),
    );
  }
}

class _TaskItem {
  _TaskItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    this.done = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  bool done;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  String _query = '';
  bool _focusMode = false;
  bool _notifications = true;
  bool _sounds = false;
  final TextEditingController _searchController = TextEditingController();

  final List<_TaskItem> _tasks = [
    _TaskItem(
      title: 'مراجعة أهداف اليوم',
      subtitle: 'الصباح · 10 دقائق',
      icon: Icons.checklist_rounded,
      tint: _mint,
    ),
    _TaskItem(
      title: 'قراءة عشر صفحات',
      subtitle: 'وقت هادئ لنفسك',
      icon: Icons.menu_book_rounded,
      tint: _lavender,
    ),
    _TaskItem(
      title: 'المشي قليلًا',
      subtitle: 'استراحة وتجديد للطاقة',
      icon: Icons.directions_walk_rounded,
      tint: _peach,
    ),
    _TaskItem(
      title: 'ترتيب مساحة العمل',
      subtitle: 'خطوة بسيطة ومفيدة',
      icon: Icons.dashboard_customize_rounded,
      tint: _softBlue,
    ),
  ];

  int get _completedCount => _tasks.where((task) => task.done).length;

  List<_TaskItem> get _filteredTasks {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _tasks;
    return _tasks
        .where((task) => task.title.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleTask(_TaskItem task, bool done) {
    setState(() => task.done = done);
    if (done && _sounds) {
      // لا يحتاج التطبيق إلى مكتبة صوتية خارجية؛ هذا الخيار محفوظ كإعداد فقط.
    }
  }

  Future<void> _addTask() async {
    final title = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.58),
      builder: (context) => const _AddTaskDialog(),
    );

    if (!mounted || title == null || title.trim().isEmpty) return;

    setState(() {
      _tasks.insert(
        0,
        _TaskItem(
          title: title.trim(),
          subtitle: 'أُضيفت للتو · على راحتك',
          icon: Icons.task_alt_rounded,
          tint: _mint,
        ),
      );
      _query = '';
      _searchController.clear();
    });
    _showMessage('تمت إضافة المهمة بنجاح');
  }

  void _toggleFocusMode() {
    setState(() => _focusMode = !_focusMode);
    _showMessage(
      _focusMode
          ? 'تم تفعيل وضع التركيز. خذ وقتك وابدأ بهدوء.'
          : 'تم إيقاف وضع التركيز.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateTo(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _currentPage() {
    switch (_selectedIndex) {
      case 1:
        return TasksScreen(
          tasks: _filteredTasks,
          searchController: _searchController,
          onSearch: (value) => setState(() => _query = value),
          onAdd: _addTask,
          onToggle: _toggleTask,
        );
      case 2:
        return SettingsScreen(
          focusMode: _focusMode,
          notifications: _notifications,
          sounds: _sounds,
          onFocusChanged: (_) => _toggleFocusMode(),
          onNotificationsChanged: (value) =>
              setState(() => _notifications = value),
          onSoundsChanged: (value) => setState(() => _sounds = value),
        );
      default:
        return HomeScreen(
          tasks: _tasks,
          completedCount: _completedCount,
          focusMode: _focusMode,
          onToggle: _toggleTask,
          onAdd: _addTask,
          onFocus: _toggleFocusMode,
          onNavigate: _navigateTo,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      extendBody: true,
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(child: _currentPage()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.space_dashboard_rounded,
                    label: 'الرئيسية',
                    selected: _selectedIndex == 0,
                    onTap: () => _navigateTo(0),
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'المهام',
                    selected: _selectedIndex == 1,
                    onTap: () => _navigateTo(1),
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    icon: Icons.tune_rounded,
                    label: 'الإعدادات',
                    selected: _selectedIndex == 2,
                    onTap: () => _navigateTo(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.tasks,
    required this.completedCount,
    required this.focusMode,
    required this.onToggle,
    required this.onAdd,
    required this.onFocus,
    required this.onNavigate,
  });

  final List<_TaskItem> tasks;
  final int completedCount;
  final bool focusMode;
  final void Function(_TaskItem task, bool done) onToggle;
  final VoidCallback onAdd;
  final VoidCallback onFocus;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final remaining = total - completedCount;
    final progress = total == 0 ? 0.0 : completedCount / total;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 124),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_mint, _softBlue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _mint.withOpacity(0.12),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: Color(0xFF12212B),
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نَسيم',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'مساحة صغيرة ليوم أهدأ',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              GlassCard(
                radius: 17,
                padding: EdgeInsets.zero,
                child: IconButton(
                  tooltip: 'البحث في المهام',
                  onPressed: () => onNavigate(1),
                  icon: const Icon(Icons.search_rounded),
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          GlassCard(
            radius: 28,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رتّب يومك،\nعلى مهل.',
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'مو مطلوب منك تنجز كل شيء.\nابدأ بخطوة صغيرة تكفي لهذا اليوم.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.7,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _mint.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _mint.withOpacity(0.16)),
                      ),
                      child: Icon(
                        focusMode ? Icons.self_improvement_rounded : Icons.spa_rounded,
                        color: _mint,
                        size: 35,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onFocus,
                    icon: Icon(
                      focusMode ? Icons.pause_rounded : Icons.center_focus_strong_rounded,
                      size: 20,
                    ),
                    label: Text(focusMode ? 'إيقاف وضع التركيز' : 'ابدأ وضع التركيز'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _mint,
                      foregroundColor: const Color(0xFF10212A),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (focusMode) ...[
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.nights_stay_rounded, size: 16, color: _mint),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'وضع التركيز مفعّل — قلّل المشتتات وخذها خطوة خطوة.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ملخص يومك',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                _arabicDate(DateTime.now()),
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.task_alt_rounded,
                  tint: _mint,
                  value: '$completedCount',
                  label: 'مهام مكتملة',
                  footnote: total == 0 ? 'ابدأ بمهمة جديدة' : 'أحسنت، استمر',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.hourglass_bottom_rounded,
                  tint: _lavender,
                  value: '$remaining',
                  label: 'مهام متبقية',
                  footnote: 'كل شيء بوقته',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GlassCard(
            radius: 21,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'تقدّمك اليوم',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: _mint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(_mint),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'مهامك القريبة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة'),
                style: TextButton.styleFrom(foregroundColor: _mint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            const _EmptyState(
              title: 'ما عندك مهام حاليًا',
              subtitle: 'أضف مهمة صغيرة وابدأ يومك بهدوء.',
              icon: Icons.spa_rounded,
            )
          else
            ...tasks.take(3).map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TaskTile(task: task, onToggle: onToggle),
                  ),
                ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: () => onNavigate(1),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('عرض جميع المهام'),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class TasksScreen extends StatelessWidget {
  const TasksScreen({
    super.key,
    required this.tasks,
    required this.searchController,
    required this.onSearch,
    required this.onAdd,
    required this.onToggle,
  });

  final List<_TaskItem> tasks;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final void Function(_TaskItem task, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    final doneCount = tasks.where((task) => task.done).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 124),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'كل مهامك',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'خطّط ببساطة، وأنجز على راحتك.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 22),
          GlassCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: searchController,
              onChanged: onSearch,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                icon: Icon(Icons.search_rounded, color: Colors.white54),
                hintText: 'ابحث عن مهمة...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            radius: 21,
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    color: _mint.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: _mint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'أنت تتقدم بطريقتك',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$doneCount من ${tasks.length} مهام ظاهرة مكتملة',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onAdd,
                  tooltip: 'إضافة مهمة',
                  icon: const Icon(Icons.add_circle_rounded, color: _mint, size: 29),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'قائمة المهام',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Text('${tasks.length} مهام', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            _EmptyState(
              title: searchController.text.trim().isEmpty
                  ? 'قائمتك فارغة الآن'
                  : 'ما لقينا هذه المهمة',
              subtitle: searchController.text.trim().isEmpty
                  ? 'أضف أول مهمة وخلي البداية بسيطة.'
                  : 'جرّب كلمة ثانية أو أضف مهمة جديدة.',
              icon: searchController.text.trim().isEmpty
                  ? Icons.checklist_rounded
                  : Icons.search_off_rounded,
              actionLabel: 'إضافة مهمة',
              onAction: onAdd,
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _TaskTile(task: task, onToggle: onToggle),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('أضف مهمة جديدة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _mint,
                side: BorderSide(color: _mint.withOpacity(0.35)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.focusMode,
    required this.notifications,
    required this.sounds,
    required this.onFocusChanged,
    required this.onNotificationsChanged,
    required this.onSoundsChanged,
  });

  final bool focusMode;
  final bool notifications;
  final bool sounds;
  final ValueChanged<bool> onFocusChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onSoundsChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 124),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الإعدادات',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'خلّي التجربة مناسبة إلك.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 26),
          const _SettingsSectionTitle(title: 'تفضيلاتك'),
          const SizedBox(height: 12),
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.center_focus_strong_rounded,
                  tint: _mint,
                  title: 'وضع التركيز',
                  subtitle: 'قلّل المشتتات وخذ وقتك',
                  value: focusMode,
                  onChanged: onFocusChanged,
                ),
                Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                _SettingRow(
                  icon: Icons.notifications_none_rounded,
                  tint: _lavender,
                  title: 'التنبيهات',
                  subtitle: 'تفضيل التنبيهات داخل التطبيق',
                  value: notifications,
                  onChanged: onNotificationsChanged,
                ),
                Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                _SettingRow(
                  icon: Icons.volume_up_rounded,
                  tint: _peach,
                  title: 'الأصوات',
                  subtitle: 'حفظ تفضيل الصوت للتجربة',
                  value: sounds,
                  onChanged: onSoundsChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const _SettingsSectionTitle(title: 'عن التطبيق'),
          const SizedBox(height: 12),
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_mint, _softBlue]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.spa_rounded, color: Color(0xFF10212A), size: 27),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('نَسيم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('مساحة هادئة لتنظيم يومك', style: TextStyle(fontSize: 12, color: Colors.white60)),
                        ],
                      ),
                    ),
                    const Text('1.0', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 17),
                const Text(
                  'صُمّم هذا النموذج بواجهة زجاجية هادئة. المهام والإعدادات تعمل داخل التطبيق خلال الجلسة الحالية، ولا يحتاج إلى اتصال بالإنترنت أو مكتبات خارجية.',
                  style: TextStyle(fontSize: 13, height: 1.7, color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 17, color: _mint.withOpacity(0.9)),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'لا يرسل هذا النموذج بياناتك إلى أي خدمة خارجية.',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'تمهّل قليلًا؛ أنت مو مطالب بكل شيء دفعة واحدة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white38, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.11),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _mint,
            activeTrackColor: _mint.withOpacity(0.30),
            inactiveTrackColor: Colors.white.withOpacity(0.08),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
    required this.footnote,
  });

  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: tint, size: 21),
          ),
          const SizedBox(height: 15),
          Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(footnote, style: TextStyle(fontSize: 10, color: tint.withOpacity(0.9))),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onToggle});

  final _TaskItem task;
  final void Function(_TaskItem task, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 21,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () => onToggle(task, !task.done),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: task.tint.withOpacity(task.done ? 0.06 : 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(task.icon, color: task.done ? Colors.white38 : task.tint, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: task.done ? Colors.white38 : Colors.white,
                          decoration: task.done ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        task.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Checkbox(
                  value: task.done,
                  onChanged: (value) => onToggle(task, value ?? false),
                  activeColor: _mint,
                  checkColor: const Color(0xFF10212A),
                  side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 23,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 27),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _mint.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: _mint, size: 29),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, height: 1.6, color: Colors.white60),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 17),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
              style: TextButton.styleFrom(foregroundColor: _mint),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _mint),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
            decoration: BoxDecoration(
              color: selected ? _mint.withOpacity(0.11) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? _mint.withOpacity(0.12) : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 21, color: selected ? _mint : Colors.white54),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? _mint : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: GlassCard(
        radius: 27,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: _mint.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_task_rounded, color: _mint, size: 25),
            ),
            const SizedBox(height: 16),
            const Text('مهمة جديدة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text(
              'اكتب شيئًا تريد إنجازه، ولو كان بسيطًا.',
              style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.6),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 80,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'عنوان المهمة',
                filled: true,
                fillColor: Colors.white.withOpacity(0.045),
                counterStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: _mint.withOpacity(0.65)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: Colors.white70, padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _mint,
                      foregroundColor: const Color(0xFF10212A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('إضافة المهمة', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.055),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.105), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF142338), _background, Color(0xFF101522)],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -110,
              right: -95,
              child: _GlowOrb(size: 310, color: const Color(0xFF3AAEAA).withOpacity(0.24)),
            ),
            Positioned(
              top: 300,
              left: -155,
              child: _GlowOrb(size: 330, color: const Color(0xFF8067D9).withOpacity(0.16)),
            ),
            Positioned(
              bottom: -170,
              right: -70,
              child: _GlowOrb(size: 290, color: const Color(0xFF508FC5).withOpacity(0.12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0.18), Colors.transparent],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

String _arabicDate(DateTime date) {
  const weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  final weekday = weekdays[(date.weekday - 1) % 7];
  final month = months[(date.month - 1) % 12];
  return '$weekday، ${date.day} $month';
}