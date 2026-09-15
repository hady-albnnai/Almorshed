import 'package:flutter/material.dart';

import '../../core/supabase/league_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/util/arabic_number.dart';

/// F4.6 — ترتيب فيزيا كلاش 🏆 (بنفسجي docs/13 — مطابقة اللوحة النموذجية).
///
/// **قرار ٦٥:** الترتيب **تراكمي طوال الموسم الدراسي** وفي **لوحة واحدة
/// بلا مجموعات** — لا يُصفَّر كل اثنين، ولا تقسيم إلى مجموعات ٣٠.
/// (القديم كان أسبوعياً بمجموعات ~٣٠؛ أُلغي بقرار المالك، والرقم ٣٠ أصلاً
/// كان بلا سند — انظر هجرة 0011.)
/// أرقام وترتيب حصراً بلا هويات، وصفّي مميز بـ«أنت». القراءة بـRLS
/// للمفعّلين حصراً.
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key, required this.fetch});

  final Future<LeagueView> Function() fetch;

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  bool _loading = true;
  String _error = '';
  LeagueView? _view;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final v = await widget.fetch();
      if (!mounted) return;
      setState(() {
        _view = v;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر جلب الترتيب — تأكد من اتصالك ثم أعد المحاولة';
        _loading = false;
      });
    }
  }

  String _medal(int rank) => switch (rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => ArabicNumber.from(rank),
      };

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final violet = dark ? AppColors.violetDark : AppColors.violetLight;
    final line = dark ? AppColors.darkLine : AppColors.lightLine;
    final card = dark ? AppColors.darkCard : AppColors.lightCard;
    final txt2 = dark ? AppColors.darkTxt2 : AppColors.lightTxt2;

    return Scaffold(
      appBar: AppBar(
        title: Text('ترتيب فيزيا كلاش 🏆',
            style: txt.titleMedium?.copyWith(color: violet)),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(_error, style: txt.bodyMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : (_view == null || _view!.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'أول إقفال للترتيب يوم الاثنين 🗓️\nزامن نقاطك (افتح التطبيق مع الإنترنت)\nليظهر اسمك على لوحة الموسم',
                          style: txt.bodyMedium?.copyWith(color: txt2),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: line),
                          ),
                          child: Text(
                            'الموسم ٢٠٢٦-٢٠٢٧ · ترتيب تراكمي'
                            ' · ${ArabicNumber.from(_view!.rows.length)} طالباً',
                            style: txt.bodyMedium?.copyWith(color: violet),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final r in _view!.rows)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: r.isMe
                                  ? violet.withValues(alpha: 0.12)
                                  : card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: r.isMe ? violet : line,
                                  width: r.isMe ? 2 : 1),
                            ),
                            child: ListTile(
                              leading: Text(_medal(r.rank),
                                  style: const TextStyle(fontSize: 20)),
                              title: Text(
                                  r.isMe ? 'أنت 🎯' : 'المركز ${ArabicNumber.from(r.rank)}',
                                  style: txt.titleSmall?.copyWith(
                                      color: r.isMe ? violet : null)),
                              trailing: Text(
                                '${ArabicNumber.from(r.xp)} نقطة',
                                style: txt.bodyMedium?.copyWith(
                                    color: dark
                                        ? AppColors.goldDark
                                        : AppColors.goldLight,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'النقاط تراكمية طوال العام الدراسي (قرار ٦٥) —\n'
                          'لوحة واحدة بلا مجموعات · التحديث كل اثنين ٠٠:٠٥ بتوقيت دمشق',
                          style: txt.bodySmall?.copyWith(color: txt2),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
    );
  }
}
